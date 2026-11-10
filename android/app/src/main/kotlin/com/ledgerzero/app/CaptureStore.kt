package com.ledgerzero.app

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.security.KeyStore
import java.security.MessageDigest
import java.security.UnrecoverableKeyException
import java.util.UUID
import javax.crypto.AEADBadTagException
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
 *   first); pending ones for [MAX_PENDING_AGE_MS]. Notifications of
 *   [NOISY_PACKAGES] that cannot be payments are not stored (no digit) or
 *   capped at [MAX_NOISY_PENDING] (nothing like an amount), so they never
 *   push waiting payments out.
 * * Seen: SHA-256 fingerprints (notification key, title, text) of recent
 *   captures with their time, so a notification that is re-posted or
 *   updated with the same text within [REPOST_WINDOW_MS] is not captured
 *   twice. (`Notification.when` is not part of it: many apps reset it on
 *   every update.)
 * * Storage reset: only when the key or the stored log is unusable for
 *   good ([isPermanent]: the key is gone, permanently invalidated or
 *   unrecoverable, the log does not authenticate or is corrupt) the log is
 *   started over with a new key and the time is kept in
 *   [PREF_STORAGE_RESET] until the Dart side has shown it to the user
 *   ([storageResetAt], [acknowledgeStorageReset]). The log is never
 *   dropped silently. Any other KeyStore or cipher failure may pass (a
 *   busy or briefly unavailable key store): the log is left as it is,
 *   [CaptureStoreUnavailableException] is thrown and the call is retried
 *   later; a notification captured meanwhile waits in memory ([backlog]).
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
        private const val MAX_BACKLOG = 100

        /**
         * Apps that post far more than payments (Google Play services
         * carries Google Wallet's tap-to-pay notifications on Pixels). The
         * Dart side has the same list
         * (NotificationCaptureService.noisyPackages) and drops their
         * notifications without an amount when it processes the log.
         */
        private val NOISY_PACKAGES = setOf("com.google.android.gms")

        /** Waiting notifications of [NOISY_PACKAGES] with nothing like an amount that are kept. */
        private const val MAX_NOISY_PENDING = 100

        /** A currency sign or code, or a number with two decimals. */
        private val AMOUNT_LIKE = Regex(
            "[€\$£¥₹]|\\b(?:EUR|USD|GBP|CHF|Euro)\\b|\\d[.,]\\d{2}(?!\\d)",
        )
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

    /**
     * Entries captured while the log could not be read or written
     * ([CaptureStoreUnavailableException]); added to the log by the next
     * call that can. Memory only: their text must not reach disk in the
     * clear.
     */
    private val backlog = mutableListOf<JSONObject>()

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
        if (NOISY_PACKAGES.contains(packageName) &&
            "${title ?: ""} $text".none { it.isDigit() }
        ) {
            // Without a digit there is no amount: not a payment, not kept.
            return false
        }
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
        val entry = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("packageName", packageName)
            .put("appLabel", appLabel)
            .put("title", title ?: JSONObject.NULL)
            .put("text", text)
            .put("postedAt", postedAt)
            .put("status", status)
            .put("f", fingerprint)
        try {
            val queue = readQueue()
            if (status == STATUS_FOUND && queue.any { it.optString("f") == fingerprint }) {
                return false
            }
            queue.add(entry)
            writeQueue(queue)
        } catch (_: CaptureStoreUnavailableException) {
            // The key store is busy: the log stays as it is and the
            // notification waits in memory for the next call.
            if (backlog.none { it.optString("f") == fingerprint }) {
                backlog.add(entry)
                while (backlog.size > MAX_BACKLOG) {
                    backlog.removeAt(0)
                }
            }
        }
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
     * failed booking, if given; [byUser] when the user chose to add it).
     */
    fun setStatus(
        ids: Set<String>,
        status: String,
        transactionId: String?,
        error: String? = null,
        byUser: Boolean = false,
    ) = synchronized(lock) {
        val queue = readQueue()
        for (entry in queue) {
            if (ids.contains(entry.optString("id"))) {
                entry.put("status", status)
                entry.put("transactionId", transactionId ?: JSONObject.NULL)
                entry.put("error", error ?: JSONObject.NULL)
                entry.put("byUser", byUser)
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
        backlog.clear()
        deleteKey()
    }

    /** Drops the unreadable log and records when, so the user can be told. */
    private fun resetStorage() {
        prefs.edit()
            .remove(PREF_QUEUE)
            .putLong(PREF_STORAGE_RESET, System.currentTimeMillis())
            .commit()
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

    /**
     * The log without expired entries, oldest first, with the entries that
     * waited in [backlog].
     *
     * Throws [CaptureStoreUnavailableException] when the key store or the
     * cipher fails in a way that may pass; the stored log is then left
     * untouched. Only a failure that is permanent ([isPermanent]) starts
     * the log over.
     */
    private fun readQueue(): MutableList<JSONObject> {
        val blob = prefs.getString(PREF_QUEUE, null)
        val array = if (blob == null) {
            JSONArray()
        } else {
            try {
                JSONArray(decrypt(blob))
            } catch (e: Exception) {
                if (!isPermanent(e)) {
                    throw CaptureStoreUnavailableException(e)
                }
                // The key is lost (vendor KeyStore reset, restored device)
                // or the data is corrupt: start over, but tell the user
                // (storageResetAt).
                if (isKeyLost(e)) {
                    deleteKey()
                }
                resetStorage()
                JSONArray()
            }
        }
        val now = System.currentTimeMillis()
        val entries = (0 until array.length())
            .mapNotNull { array.optJSONObject(it) }
            .filter {
                val maxAge = if (isPending(it)) MAX_PENDING_AGE_MS else MAX_LOG_AGE_MS
                it.optLong("postedAt") >= now - maxAge
            }
            .toMutableList()
        if (backlog.isNotEmpty()) {
            val known = entries.map { it.optString("id") }.toSet()
            entries.addAll(backlog.filterNot { known.contains(it.optString("id")) })
            try {
                writeQueue(entries)
            } catch (_: CaptureStoreUnavailableException) {
                // Still in memory; the next call tries again.
            }
        }
        return entries
    }

    /**
     * Writes the log synchronously (`commit`): the process may be killed
     * right after a capture, and an `apply` that never reached the disk
     * would lose it.
     */
    private fun writeQueue(entries: List<JSONObject>) {
        val editor = prefs.edit()
        if (entries.isEmpty()) {
            editor.remove(PREF_QUEUE)
        } else {
            val array = JSONArray()
            capped(entries).forEach { array.put(it) }
            editor.putString(PREF_QUEUE, encrypt(array.toString()))
        }
        if (!editor.commit()) {
            throw CaptureStoreUnavailableException(IOException("The capture log could not be written"))
        }
        backlog.clear()
    }

    /** A waiting notification of a noisy app with nothing like an amount. */
    private fun isNoisyJunk(entry: JSONObject): Boolean =
        isPending(entry) &&
            NOISY_PACKAGES.contains(entry.optString("packageName")) &&
            !AMOUNT_LIKE.containsMatchIn("${entry.optString("title")} ${entry.optString("text")}")

    /**
     * [entries] within the limits: at most [MAX_NOISY_PENDING] waiting
     * notifications of noisy apps that cannot be payments, and at most
     * [MAX_ENTRIES] in all. Dropped in this order, oldest first: handled
     * entries, then that noise, and only then waiting payments.
     */
    private fun capped(entries: List<JSONObject>): List<JSONObject> {
        var kept = entries
        val noise = kept.filter(::isNoisyJunk)
        if (noise.size > MAX_NOISY_PENDING) {
            val dropped = noise.take(noise.size - MAX_NOISY_PENDING).toSet()
            kept = kept.filterNot { dropped.contains(it) }
        }
        for (expendable in listOf<(JSONObject) -> Boolean>({ !isPending(it) }, ::isNoisyJunk)) {
            val excess = kept.size - MAX_ENTRIES
            if (excess <= 0) {
                break
            }
            val dropped = kept.filter(expendable).take(excess).toSet()
            kept = kept.filterNot { dropped.contains(it) }
        }
        return kept.takeLast(MAX_ENTRIES)
    }

    // ---------------------------------------------------------------------
    // Encryption
    // ---------------------------------------------------------------------

    /** The key exists but can never be used again. */
    private fun isKeyLost(e: Throwable): Boolean =
        e is KeyPermanentlyInvalidatedException || e is UnrecoverableKeyException

    /**
     * Whether [e] means that the stored log can never be read: the key is
     * lost ([isKeyLost]), the log does not authenticate under the key
     * (another key, or tampered data) or it is not what this class wrote.
     * Everything else (a busy or unavailable key store, a provider error)
     * may pass.
     */
    private fun isPermanent(e: Throwable): Boolean =
        isKeyLost(e) || e is AEADBadTagException || e is CorruptLogException || e is JSONException

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    /**
     * The log key; a new one when there is none (first use, or the key
     * store lost it: an existing log then fails to authenticate, which
     * [readQueue] reports as a storage reset). Key store errors are thrown
     * to the caller, never answered by replacing the key here.
     */
    private fun key(): SecretKey {
        val store = keyStore()
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        if (store.containsAlias(KEY_ALIAS)) {
            // Listed but not returned: the key store is not answering
            // properly right now. A new key would replace the real one.
            throw CaptureStoreUnavailableException(
                IllegalStateException("The capture key is listed but not available"),
            )
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
        fun seal(): String {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key())
            val sealed = cipher.iv + cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
            return Base64.encodeToString(sealed, Base64.NO_WRAP)
        }
        return try {
            seal()
        } catch (e: CaptureStoreUnavailableException) {
            throw e
        } catch (e: Exception) {
            if (!isKeyLost(e)) {
                throw CaptureStoreUnavailableException(e)
            }
            // The key cannot be used any more. What is being written is
            // the whole log, so nothing is lost by sealing it with a new
            // key.
            deleteKey()
            try {
                seal()
            } catch (e2: Exception) {
                throw CaptureStoreUnavailableException(e2)
            }
        }
    }

    private fun decrypt(blob: String): String {
        val sealed = try {
            Base64.decode(blob, Base64.NO_WRAP)
        } catch (e: IllegalArgumentException) {
            throw CorruptLogException(e)
        }
        if (sealed.size <= 12) {
            throw CorruptLogException(null)
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed, 0, 12))
        return String(cipher.doFinal(sealed, 12, sealed.size - 12), Charsets.UTF_8)
    }

    /** The stored log is not Base64 of IV + ciphertext. */
    private class CorruptLogException(cause: Throwable?) : Exception(cause)

    private fun sha256(text: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}

/**
 * The capture log could not be read or written right now (the key store or
 * the cipher failed in a way that may pass). Nothing was dropped; the call
 * can be repeated later.
 */
class CaptureStoreUnavailableException(cause: Throwable) : Exception(cause)
