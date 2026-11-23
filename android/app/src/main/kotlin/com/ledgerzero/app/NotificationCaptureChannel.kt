package com.ledgerzero.app

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Method channel for card notification capture (Dart side:
 * lib/services/notification_capture/notification_capture_channel.dart).
 *
 * Calls Dart's `captured` when the listener queued a notification while
 * the engine is running, so an unlocked app picks it up at once.
 */
class NotificationCaptureChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.ledgerzero.app/notification_capture"

        /**
         * Bank, card and wallet apps offered in the app picker when they
         * are installed (each is also listed under <queries> in the
         * manifest, otherwise package visibility hides it).
         */
        private val KNOWN_APPS = listOf(
            "com.google.android.apps.walletnfcrel",
            // Pixels post Google Wallet's tap-to-pay notifications from
            // Google Play services, not from the Wallet app.
            "com.google.android.gms",
            "com.paypal.android.p2pmobile",
            "com.revolut.revolut",
            "de.number26.android",
            "de.ingdiba.bankingapp",
            "com.starfinanz.smob.android.sfinanzstatus",
            "de.commerzbanking.mobil",
            "de.comdirect.android",
            "com.dkbcodefactory.banking",
            "de.dkb.portalapp",
            "de.traderepublic.app",
            "com.db.pwcc.dbmobile",
            "de.postbank.finanzassistent",
            "com.transferwise.android",
            "com.bunq.android",
            "com.imaginecurve.curve.prd",
            "co.uk.getmondo",
            "com.chase.sig.android",
            "com.konylabs.capitalone",
            "com.americanexpress.android.acctsvcs.us",
        )

        /** Picker labels that say what is captured better than the app's own name. */
        private val KNOWN_LABELS = mapOf(
            "com.google.android.gms" to "Google Wallet (tap to pay via Google Play services)",
        )
    }

    private val store = CaptureStore.get(activity)
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    @Volatile
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
        CaptureStore.onCaptured = {
            if (!disposed) {
                mainHandler.post {
                    if (!disposed) {
                        channel.invokeMethod("captured", null)
                    }
                }
            }
        }
        // After an app update the system may leave the listener unbound
        // until the next reboot; asking for a rebind brings it back.
        CardNotificationListener.requestRebindIfNeeded(activity)
    }

    /** Stops forwarding captures (the engine is going away). */
    fun dispose() {
        disposed = true
        CaptureStore.onCaptured = null
        mainHandler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
        ioExecutor.shutdown()
    }

    private fun runOffMain(result: MethodChannel.Result, block: () -> Any?) {
        ioExecutor.execute {
            try {
                val value = block()
                mainHandler.post {
                    if (!disposed) {
                        result.success(value)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    if (!disposed) {
                        result.error("failed", e.javaClass.simpleName, null)
                    }
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAccessGranted" -> result.success(isAccessGranted())
                "isListenerConnected" -> {
                    // Asked at start and on every resume: a listener the
                    // system dropped meanwhile is asked back.
                    CardNotificationListener.requestRebindIfNeeded(activity)
                    result.success(CardNotificationListener.connected != null)
                }
                "storageResetAt" -> runOffMain(result) { store.storageResetAt() }
                "acknowledgeStorageReset" -> runOffMain(result) {
                    store.acknowledgeStorageReset()
                    null
                }
                "openAccessSettings" -> {
                    openAccessSettings()
                    result.success(null)
                }
                "getSources" -> runOffMain(result) { store.sources().toString() }
                "setSources" -> {
                    val raw = call.argument<String>("sources") ?: "[]"
                    runOffMain(result) {
                        store.setSources(JSONArray(raw))
                        null
                    }
                }
                "candidateApps" -> runOffMain(result) { candidateApps().toString() }
                "pending" -> runOffMain(result) { store.pending().toString() }
                "log" -> runOffMain(result) { store.log().toString() }
                "setStatus" -> {
                    val ids = call.argument<List<String>>("ids")?.toSet() ?: emptySet()
                    val status = call.argument<String>("status") ?: CaptureStore.STATUS_PENDING
                    val transactionId = call.argument<String>("transactionId")
                    val error = call.argument<String>("error")
                    val byUser = call.argument<Boolean>("byUser") ?: false
                    runOffMain(result) {
                        store.setStatus(ids, status, transactionId, error, byUser)
                        null
                    }
                }
                "captureShowing" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    runOffMain(result) {
                        CardNotificationListener.connected?.captureShowing(pkg) ?: 0
                    }
                }
                "remove" -> {
                    val ids = call.argument<List<String>>("ids")?.toSet() ?: emptySet()
                    runOffMain(result) {
                        store.remove(ids)
                        null
                    }
                }
                "clear" -> runOffMain(result) {
                    store.clear()
                    null
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("failed", e.javaClass.simpleName, null)
        }
    }

    private fun isAccessGranted(): Boolean = CardNotificationListener.isAccessGranted(activity)

    private fun openAccessSettings() {
        val component = ComponentName(activity, CardNotificationListener::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val detail = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
            try {
                activity.startActivity(detail)
                return
            } catch (_: Exception) {
                // Some vendors lack the detail screen; open the list.
            }
        }
        activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    /**
     * Apps the user can choose from: apps with a notification showing now,
     * apps that posted one recently, and installed known bank apps.
     */
    private fun candidateApps(): JSONArray {
        val apps = LinkedHashMap<String, Pair<String, String>>()
        CardNotificationListener.connected?.activeApps()?.forEach { (pkg, label) ->
            apps[pkg] = label to "active"
        }
        CardNotificationListener.recentApps().entries.reversed().forEach { (pkg, label) ->
            apps.putIfAbsent(pkg, label to "recent")
        }
        val pm = activity.packageManager
        for (pkg in KNOWN_APPS) {
            if (apps.containsKey(pkg)) {
                continue
            }
            try {
                val info = pm.getApplicationInfo(pkg, 0)
                val label = KNOWN_LABELS[pkg] ?: pm.getApplicationLabel(info).toString()
                apps[pkg] = label to "known"
            } catch (_: Exception) {
                // Not installed.
            }
        }
        val array = JSONArray()
        for ((pkg, value) in apps) {
            array.put(
                JSONObject()
                    .put("packageName", pkg)
                    .put("label", value.first)
                    .put("origin", value.second),
            )
        }
        return array
    }
}
