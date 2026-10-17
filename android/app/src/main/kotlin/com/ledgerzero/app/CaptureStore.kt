package com.ledgerzero.app

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * On-device storage for card notification capture.
 *
 * * Sources: the apps the user chose to watch (package, label, linked
 *   account id) as JSON. The listener only looks at notifications from
 *   these packages.
 * * Queue: captured notifications (title, text, time) waiting for the
 *   Flutter side. The listener runs even when the app (and its database)
 *   is closed, so it writes here and the Dart side turns entries into
 *   transactions when the app next starts. The queue is encrypted with an
 *   AES-256-GCM key in the Android KeyStore (no user authentication); only
 *   IV + ciphertext reach SharedPreferences.
 *   At most [MAX_QUEUE] entries are kept, none older than [MAX_AGE_MS].
 * * Seen: SHA-256 fingerprints (notification key, title, text) of recent
 *   captures with their time, so a notification that is re-posted or
 *   updated with the same text within [REPOST_WINDOW_MS] is not captured
 *   twice. (`Notification.when` is not part of it: many apps reset it on
 *   every update.)
 *
 * All access is serialised on [lock]; the listener and the method channel
 * run in the same process.
 */
class CaptureStore private constructor(context: Context) {

    companion object {
        private const val PREFS = "ledgerzero_capture"
        private const val PREF_SOURCES = "sources"
        private const val PREF_QUEUE = "queue"
        private const val PREF_SEEN = "seen"
        private const val KEY_ALIAS = "ledgerzero_capture_key"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val MAX_QUEUE = 200
        private const val MAX_SEEN = 100
        private const val MAX_AGE_MS = 90L * 24 * 60 * 60 * 1000
        private const val REPOST_WINDOW_MS = 2L * 60 * 1000

        @Volatile
        private var instance: CaptureStore? = null

        /** Called (on the listener's thread) after an entry was queued. */
        @Volatile
        var onCaptured: (() -> Unit)? = null

        fun get(context: Context): CaptureStore =
            instance ?: synchronized(this) {
                instance ?: CaptureStore(context.applicationContext).also { instance = it }
            }
    }

    private val lock = Any()
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Volatile
    private var watched: Set<String>? = null

    // ---------------------------------------------------------------------
    // Sources
    // ---------------------------------------------------------------------

    fun sources(): JSONArray = synchronized(lock) {
        JSONArray(prefs.getString(PREF_SOURCES, null) ?: "[]")
    }

    fun setSources(sources: JSONArray) = synchronized(lock) {
        prefs.edit().putString(PREF_SOURCES, sources.toString()).apply()
        watched = null
    }

    fun watchedPackages(): Set<String> {
        watched?.let { return it }
        val array = sources()
        val packages = (0 until array.length())
            .mapNotNull { array.optJSONObject(it)?.optString("packageName") }
            .filter { it.isNotEmpty() }
            .toSet()
        watched = packages
        return packages
    }

    // ---------------------------------------------------------------------
    // Queue
    // ---------------------------------------------------------------------

    /**
     * Queues a notification unless the same one ([key], title, text) was
     * captured less than [REPOST_WINDOW_MS] before. Returns whether it was
     * queued.
     */
    fun append(
        packageName: String,
        appLabel: String,
        key: String,
        title: String?,
        text: String,
        postedAt: Long,
    ): Boolean = synchronized(lock) {
        val fingerprint = sha256("$key|$title|$text")
        val now = System.currentTimeMillis()
        val seen = try {
            JSONArray(prefs.getString(PREF_SEEN, null) ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        for (i in 0 until seen.length()) {
            val entry = seen.optJSONObject(i) ?: continue
            if (entry.optString("f") == fingerprint &&
                now - entry.optLong("t") < REPOST_WINDOW_MS
            ) {
                return false
            }
        }
        val queue = readQueue()
        queue.add(
            JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("packageName", packageName)
                .put("appLabel", appLabel)
                .put("title", title ?: JSONObject.NULL)
                .put("text", text)
                .put("postedAt", postedAt),
        )
        writeQueue(queue)
        val newSeen = JSONArray().put(JSONObject().put("f", fingerprint).put("t", now))
        for (i in 0 until minOf(seen.length(), MAX_SEEN - 1)) {
            seen.optJSONObject(i)?.let { newSeen.put(it) }
        }
        prefs.edit().putString(PREF_SEEN, newSeen.toString()).apply()
        true
    }

    fun pending(): JSONArray = synchronized(lock) {
        JSONArray().apply { readQueue().forEach { put(it) } }
    }

    fun remove(ids: Set<String>) = synchronized(lock) {
        writeQueue(readQueue().filterNot { ids.contains(it.optString("id")) })
    }

    /** Removes everything: sources, queue, fingerprints and the key. */
    fun clear() = synchronized(lock) {
        prefs.edit().clear().apply()
        watched = null
        val ks = keyStore()
        if (ks.containsAlias(KEY_ALIAS)) {
            ks.deleteEntry(KEY_ALIAS)
        }
    }

    /** The queue without entries older than [MAX_AGE_MS]. */
    private fun readQueue(): MutableList<JSONObject> {
        val blob = prefs.getString(PREF_QUEUE, null) ?: return mutableListOf()
        val array = try {
            JSONArray(decrypt(blob))
        } catch (e: Exception) {
            // Key lost (e.g. restored device) or corrupt data: start over.
            prefs.edit().remove(PREF_QUEUE).apply()
            return mutableListOf()
        }
        val cutoff = System.currentTimeMillis() - MAX_AGE_MS
        return (0 until array.length())
            .mapNotNull { array.optJSONObject(it) }
            .filter { it.optLong("postedAt") >= cutoff }
            .toMutableList()
    }

    private fun writeQueue(entries: List<JSONObject>) {
        if (entries.isEmpty()) {
            prefs.edit().remove(PREF_QUEUE).apply()
            return
        }
        val array = JSONArray()
        entries.takeLast(MAX_QUEUE).forEach { array.put(it) }
        prefs.edit().putString(PREF_QUEUE, encrypt(array.toString())).apply()
    }

    // ---------------------------------------------------------------------
    // Encryption
    // ---------------------------------------------------------------------

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun key(): SecretKey {
        val ks = keyStore()
        (ks.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val sealed = cipher.iv + cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(sealed, Base64.NO_WRAP)
    }

    private fun decrypt(blob: String): String {
        val sealed = Base64.decode(blob, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed, 0, 12))
        return String(cipher.doFinal(sealed, 12, sealed.size - 12), Charsets.UTF_8)
    }

    private fun sha256(text: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}
