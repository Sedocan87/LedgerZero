package com.ledgerzero.app

import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The app lock: the system prompt for a fingerprint/face or the device
 * PIN, pattern or password (Dart side:
 * lib/services/security/app_lock_authenticator.dart).
 *
 * It gates the UI only; the database key does not depend on it (see
 * DeviceKeyStore). API 30+ allows a strong biometric or the device
 * credential; below API 30 BIOMETRIC_STRONG cannot be combined with
 * DEVICE_CREDENTIAL, so a weak biometric or the device credential is used
 * there.
 */
class AppLockChannel(
    private val activity: FragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.ledgerzero.app/app_lock"
    }

    private val authenticators =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            BIOMETRIC_STRONG or DEVICE_CREDENTIAL
        } else {
            BIOMETRIC_WEAK or DEVICE_CREDENTIAL
        }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "canAuthenticate" -> result.success(canAuthenticate())
                "authenticate" -> authenticate(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("failed", e.javaClass.simpleName, null)
        }
    }

    /** Whether the device has a screen lock or an enrolled biometric. */
    private fun canAuthenticate(): Boolean =
        BiometricManager.from(activity).canAuthenticate(authenticators) ==
            BiometricManager.BIOMETRIC_SUCCESS

    private fun authenticate(call: MethodCall, result: MethodChannel.Result) {
        if (!canAuthenticate()) {
            result.error("unavailable", null, null)
            return
        }
        var replied = false
        fun reply(block: () -> Unit) {
            if (!replied) {
                replied = true
                block()
            }
        }
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                reply { result.success(true) }
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
        // No negative button: it is not allowed together with
        // DEVICE_CREDENTIAL (the system shows its own cancel).
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(call.argument<String>("title") ?: "LedgerZero")
            .setSubtitle(call.argument<String>("subtitle"))
            .setAllowedAuthenticators(authenticators)
            .setConfirmationRequired(false)
            .build()
        BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
            .authenticate(info)
    }
}
