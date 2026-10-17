package com.ledgerzero.app

import android.content.Context
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Reads the database key that installs from before the device key stored
 * for biometric unlock (it can only be recovered after a fresh
 * BIOMETRIC_STRONG authentication). Used once to move the key to the
 * device key store; nothing new is stored any more.
 *
 * The key was an AES-256-GCM key in the Android KeyStore with
 * setUserAuthenticationRequired(true), per-use authentication (timeout 0 on
 * API 30+, validity -1 below) and setInvalidatedByBiometricEnrollment(true).
 * The secret is decrypted only through a
 * BiometricPrompt.CryptoObject wrapping that key; only IV + ciphertext are
 * written to SharedPreferences. Enrolling a new fingerprint/face invalidates
 * the key (KeyPermanentlyInvalidatedException); the entry is then deleted.
 */
class BiometricKeyChannel(
    private val activity: FragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.ledgerzero.app/biometric_key"
        private const val KEY_ALIAS = "ledgerzero_biometric_kek"
        private const val PREFS = "ledgerzero_biometric"
        private const val PREF_BLOB = "wrapped_dek"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(isAvailable())
                "hasKey" -> result.success(hasKey())
                "read" -> read(call, result)
                "delete" -> {
                    delete()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("failed", e.javaClass.simpleName, null)
        }
    }

    private fun isAvailable(): Boolean =
        BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    private fun prefs() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun hasKey(): Boolean =
        prefs().contains(PREF_BLOB) && keyStore().containsAlias(KEY_ALIAS)

    private fun delete() {
        prefs().edit().remove(PREF_BLOB).apply()
        val ks = keyStore()
        if (ks.containsAlias(KEY_ALIAS)) {
            ks.deleteEntry(KEY_ALIAS)
        }
    }

    private fun read(call: MethodCall, result: MethodChannel.Result) {
        val blob = prefs().getString(PREF_BLOB, null)
        val key = keyStore().getKey(KEY_ALIAS, null) as SecretKey?
        if (blob == null || key == null) {
            result.error("not_found", null, null)
            return
        }
        val parts = blob.split(":")
        if (parts.size != 2) {
            delete()
            result.error("not_found", null, null)
            return
        }
        val iv = Base64.decode(parts[0], Base64.NO_WRAP)
        val ciphertext = Base64.decode(parts[1], Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        try {
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
        } catch (e: KeyPermanentlyInvalidatedException) {
            delete()
            result.error("invalidated", null, null)
            return
        }
        authenticate(call, cipher, result) { authenticated -> authenticated.doFinal(ciphertext) }
    }

    /** Shows the prompt; [onSuccess] runs with the authenticated cipher. */
    private fun authenticate(
        call: MethodCall,
        cipher: Cipher,
        result: MethodChannel.Result,
        onSuccess: (Cipher) -> Any?,
    ) {
        var replied = false
        fun reply(block: () -> Unit) {
            if (!replied) {
                replied = true
                block()
            }
        }
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                val authenticated = authResult.cryptoObject?.cipher
                if (authenticated == null) {
                    reply { result.error("failed", "no cipher", null) }
                    return
                }
                try {
                    val value = onSuccess(authenticated)
                    reply { result.success(value) }
                } catch (e: Exception) {
                    reply { result.error("failed", e.javaClass.simpleName, null) }
                }
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                val code = when (errorCode) {
                    BiometricPrompt.ERROR_USER_CANCELED,
                    BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                    BiometricPrompt.ERROR_CANCELED -> "cancelled"
                    BiometricPrompt.ERROR_NO_BIOMETRICS,
                    BiometricPrompt.ERROR_HW_NOT_PRESENT,
                    BiometricPrompt.ERROR_HW_UNAVAILABLE,
                    BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "unavailable"
                    else -> "failed"
                }
                reply { result.error(code, errString.toString(), null) }
            }

            override fun onAuthenticationFailed() {
                // A non-matching attempt; the prompt stays open.
            }
        }
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(call.argument<String>("title") ?: "LedgerZero")
            .setSubtitle(call.argument<String>("subtitle"))
            .setNegativeButtonText(call.argument<String>("cancel") ?: "Cancel")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()
        val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
        prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
    }
}
