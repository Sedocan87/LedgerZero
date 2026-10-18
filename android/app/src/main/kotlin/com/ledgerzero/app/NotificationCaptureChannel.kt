package com.ledgerzero.app

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
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
    }

    private val store = CaptureStore.get(activity)
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
        CaptureStore.onCaptured = {
            mainHandler.post { channel.invokeMethod("captured", null) }
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
                apps[pkg] = pm.getApplicationLabel(info).toString() to "known"
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
