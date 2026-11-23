package com.reinlogic.play_age_features

import android.content.Context
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.ApplicableAgeFeaturesRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes Play Age Signals' getApplicableAgeFeatures() (library 0.0.6) to Dart.
 *
 * Errors reach Dart as a PlatformException whose code is Play's numeric
 * AgeSignalsErrorCode (as a string), or "UNKNOWN" for a non-Play failure.
 */
class PlayAgeFeaturesPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    @Volatile
    private var attached = false

    /** Created on first use; tests can set a FakeAgeSignalsManager. */
    internal var manager: AgeSignalsManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        manager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getApplicableAgeFeatures" -> getApplicableAgeFeatures(result)
            else -> result.notImplemented()
        }
    }

    private fun getApplicableAgeFeatures(result: MethodChannel.Result) {
        val manager = manager ?: context?.let { AgeSignalsManagerFactory.create(it) }
            ?.also { manager = it }
        if (manager == null) {
            result.error("UNKNOWN", "Plugin is not attached to an engine", null)
            return
        }
        try {
            manager.getApplicableAgeFeatures(ApplicableAgeFeaturesRequest.builder().build())
                .addOnSuccessListener { features ->
                    if (attached) {
                        result.success(features.features().toList())
                    }
                }
                .addOnFailureListener { e ->
                    if (attached) {
                        result.error(errorCode(e), e.message, null)
                    }
                }
        } catch (e: Exception) {
            // The library can throw synchronously on very old Play setups.
            if (attached) {
                result.error(errorCode(e), e.message, null)
            }
        }
    }

    private fun errorCode(e: Exception): String =
        if (e is AgeSignalsException) e.errorCode.toString() else "UNKNOWN"

    companion object {
        const val CHANNEL = "com.reinlogic/play_age_features"
    }
}
