package com.ledgerzero.app

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

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

    init {
        channel.setMethodCallHandler(this)
        CaptureStore.onCaptured = {
            mainHandler.post { channel.invokeMethod("captured", null) }
        }
        requestRebind()
    }

    /**
     * After an app update the system may leave the listener unbound until
     * the next reboot; asking for a rebind at start brings it back.
     */
    private fun requestRebind() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || !isAccessGranted()) {
            return
        }
        if (CardNotificationListener.connected != null) {
            return
        }
        try {
            NotificationListenerService.requestRebind(
                ComponentName(activity, CardNotificationListener::class.java),
            )
        } catch (_: Exception) {
            // Not granted after all, or the system refuses; the settings
            // screen shows that the listener is not connected.
        }
    }

    /** Stops forwarding captures (the engine is going away). */
    fun dispose() {
        CaptureStore.onCaptured = null
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAccessGranted" -> result.success(isAccessGranted())
                "isListenerConnected" -> result.success(CardNotificationListener.connected != null)
                "storageResetAt" -> result.success(store.storageResetAt())
                "acknowledgeStorageReset" -> {
                    store.acknowledgeStorageReset()
                    result.success(null)
                }
                "openAccessSettings" -> {
                    openAccessSettings()
                    result.success(null)
                }
                "getSources" -> result.success(store.sources().toString())
                "setSources" -> {
                    store.setSources(JSONArray(call.argument<String>("sources") ?: "[]"))
                    result.success(null)
                }
                "candidateApps" -> result.success(candidateApps().toString())
                "pending" -> result.success(store.pending().toString())
                "log" -> result.success(store.log().toString())
                "setStatus" -> {
                    store.setStatus(
                        call.argument<List<String>>("ids")?.toSet() ?: emptySet(),
                        call.argument<String>("status") ?: CaptureStore.STATUS_PENDING,
                        call.argument<String>("transactionId"),
                        call.argument<String>("error"),
                    )
                    result.success(null)
                }
                "captureShowing" -> result.success(
                    CardNotificationListener.connected
                        ?.captureShowing(call.argument<String>("packageName") ?: "")
                        ?: 0,
                )
                "remove" -> {
                    store.remove(call.argument<List<String>>("ids")?.toSet() ?: emptySet())
                    result.success(null)
                }
                "clear" -> {
                    store.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("failed", e.javaClass.simpleName, null)
        }
    }

    private fun isAccessGranted(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(activity)
            .contains(activity.packageName)

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
