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
 * * Log: captured notifications (title, text, time, status). The
 *   listener runs even when the app (and its database) is closed, so it
 *   writes `pending` entries here and the Dart side turns them into
 *   transactions when the app next starts. Dart then sets the status
 *   (`added`, `skipped`, `dismissed`; `found` for notifications that were
 *   already showing when their app was added) and the entry stays for
 *   [MAX_LOG_AGE_MS], so the user can add a payment again. The log is
 *   encrypted with an AES-256-GCM key in the Android KeyStore (no user
 *   authentication); only IV + ciphertext reach SharedPreferences.
 *   At most [MAX_ENTRIES] entries are kept (handled ones are dropped
 *   first); pending ones for [MAX_PENDING_AGE_MS].
 * * Seen: SHA-256 fingerprints (notification key, title, text) of recent
 *   captures with their time, so a notification that is re-posted or
 *   updated with the same text within [REPOST_WINDOW_MS] is not captured
 *   twice. (`Notification.when` is not part of it: many apps reset it on
 *   every update.)
 * * Storage reset: when the KeyStore key is gone or no longer usable (a
 *   vendor KeyStore reset, a restored device) the log cannot be read; it
 *   is started over with a new key and the time is kept in
 *   [PREF_STORAGE_RESET] until the Dart side has shown it to the user
 *   ([storageResetAt], [acknowledgeStorageReset]). The log is never
 *   dropped silently.
 *
 * All access is serialised on [lock]; the listener and the method channel
 * run in the same process.
 */
class CaptureStore private constructor(context: Context) {

    companion object {
        private const val PREFS = "ledgerzero_capture"
        private const val PREF_SOURCES = "sources"
        // The log; named after the queue it was before it kept handled
        // entries (entries without a status are pending).
        private const val PREF_QUEUE = "queue"
        private const val PREF_SEEN = "seen"
        private const val PREF_STORAGE_RESET = "storageResetAt"
        private const val KEY_ALIAS = "ledgerzero_capture_key"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val MAX_ENTRIES = 500
        private const val MAX_SEEN = 100
        private const val MAX_PENDING_AGE_MS = 90L * 24 * 60 * 60 * 1000
        private const val MAX_LOG_AGE_MS = 30L * 24 * 60 * 60 * 1000

        const val STATUS_PENDING = "pending"
        const val STATUS_FOUND = "found"
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
    // Log
    // ---------------------------------------------------------------------

    /**
     * Logs a notification with [status] unless the same one ([key], title,
     * text) was captured less than [REPOST_WINDOW_MS] before or, for
     * [STATUS_FOUND], is in the log already. Returns whether it was logged.
     */
    fun append(
        packageName: String,
        appLabel: String,
        key: String,
        title: String?,
        text: String,
        postedAt: Long,
        status: String = STATUS_PENDING,
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
        if (status == STATUS_FOUND && queue.any { it.optString("f") == fingerprint }) {
            return false
        }
        queue.add(
            JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("packageName", packageName)
                .put("appLabel", appLabel)
                .put("title", title ?: JSONObject.NULL)
                .put("text", text)
                .put("postedAt", postedAt)
                .put("status", status)
                .put("f", fingerprint),
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
        JSONArray().apply { readQueue().filter(::isPending).forEach { put(it) } }
    }

    /** Every logged entry, oldest first. */
    fun log(): JSONArray = synchronized(lock) {
        JSONArray().apply { readQueue().forEach { put(it) } }
    }

    /**
     * Sets the status (and the booked transaction's id, or the error of a
     * failed booking, if given).
     */
    fun setStatus(
        ids: Set<String>,
        status: String,
        transactionId: String?,
        error: String? = null,
    ) = synchronized(lock) {
        val queue = readQueue()
        for (entry in queue) {
            if (ids.contains(entry.optString("id"))) {
                entry.put("status", status)
                entry.put("transactionId", transactionId ?: JSONObject.NULL)
                entry.put("error", error ?: JSONObject.NULL)
            }
        }
        writeQueue(queue)
    }

    /** When the log was last started over because its key was lost; 0 if never or acknowledged. */
    fun storageResetAt(): Long = synchronized(lock) { prefs.getLong(PREF_STORAGE_RESET, 0L) }

    fun acknowledgeStorageReset() = synchronized(lock) {
        prefs.edit().remove(PREF_STORAGE_RESET).apply()
    }

    fun remove(ids: Set<String>) = synchronized(lock) {
        writeQueue(readQueue().filterNot { ids.contains(it.optString("id")) })
    }

    /** Removes everything: sources, log, fingerprints and the key. */
    fun clear() = synchronized(lock) {
        prefs.edit().clear().apply()
        watched = null
        deleteKey()
    }

    /** Drops the unreadable log and records when, so the user can be told. */
    private fun resetStorage() {
        prefs.edit()
            .remove(PREF_QUEUE)
            .putLong(PREF_STORAGE_RESET, System.currentTimeMillis())
            .apply()
    }

    private fun deleteKey() {
        try {
            val ks = keyStore()
            if (ks.containsAlias(KEY_ALIAS)) {
                ks.deleteEntry(KEY_ALIAS)
            }
        } catch (_: Exception) {
            // Nothing to delete, or the key store refuses; a new key is
            // generated under the same alias either way.
        }
    }

    private fun isPending(entry: JSONObject): Boolean =
        entry.optString("status", STATUS_PENDING).let { it.isEmpty() || it == STATUS_PENDING }

    /** The log without expired entries, oldest first. */
    private fun readQueue(): MutableList<JSONObject> {
        val blob = prefs.getString(PREF_QUEUE, null) ?: return mutableListOf()
        val array = try {
            JSONArray(decrypt(blob))
        } catch (e: Exception) {
            // Key lost (e.g. restored device) or corrupt data: start over,
            // but tell the user (storageResetAt).
            resetStorage()
            return mutableListOf()
        }
        val now = System.currentTimeMillis()
        return (0 until array.length())
            .mapNotNull { array.optJSONObject(it) }
            .filter {
                val maxAge = if (isPending(it)) MAX_PENDING_AGE_MS else MAX_LOG_AGE_MS
                it.optLong("postedAt") >= now - maxAge
            }
            .toMutableList()
    }

    private fun writeQueue(entries: List<JSONObject>) {
        if (entries.isEmpty()) {
            prefs.edit().remove(PREF_QUEUE).apply()
            return
        }
        var kept = entries
        if (kept.size > MAX_ENTRIES) {
            // Oldest handled entries go first, then the oldest pending ones.
            val excess = kept.size - MAX_ENTRIES
            val handled = kept.filterNot(::isPending).take(excess).toSet()
            kept = kept.filterNot { handled.contains(it) }.takeLast(MAX_ENTRIES)
        }
        val array = JSONArray()
        kept.forEach { array.put(it) }
        prefs.edit().putString(PREF_QUEUE, encrypt(array.toString())).apply()
    }

    // ---------------------------------------------------------------------
    // Encryption
    // ---------------------------------------------------------------------

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun key(): SecretKey {
        try {
            (keyStore().getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        } catch (e: Exception) {
            // UnrecoverableKeyException / KeyStoreException: the key exists
            // but cannot be used any more (vendor KeyStore reset). The old
            // log is unreadable either way; start over with a new key and
            // record it for the user.
            deleteKey()
            resetStorage()
        }
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
