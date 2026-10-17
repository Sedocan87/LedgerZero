package com.ledgerzero.app

import android.app.Notification
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Captures notifications of the apps the user chose in Settings > Card
 * notifications (bank, card or wallet apps) and queues their text in
 * [CaptureStore]. Notifications of every other app are ignored without
 * reading their content.
 *
 * The system binds this service only after the user granted notification
 * access in the system settings. Parsing and saving happen in Dart after
 * the next unlock (see lib/services/notification_capture/).
 */
class CardNotificationListener : NotificationListenerService() {

    companion object {
        /** The connected listener, for listing apps with notifications. */
        @Volatile
        var connected: CardNotificationListener? = null
            private set

        private const val MAX_RECENT_APPS = 30

        /**
         * Packages (never content) of apps that posted a notification
         * while this process was alive (oldest first), so the app picker
         * can offer a bank app whose notification was already dismissed.
         * Kept in memory only.
         */
        private val recentApps = LinkedHashMap<String, String>()

        fun recentApps(): Map<String, String> = synchronized(recentApps) {
            LinkedHashMap(recentApps)
        }

        /** The user-visible name of [packageName], or the package name. */
        fun appLabel(context: Context, packageName: String, notification: Notification?): String {
            val pm = context.packageManager
            try {
                return pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
            } catch (_: PackageManager.NameNotFoundException) {
                // Not visible to this app (package visibility); fall through.
            }
            @Suppress("DEPRECATION")
            val info = notification?.extras?.get("android.appInfo") as? ApplicationInfo
            if (info != null) {
                try {
                    return info.loadLabel(pm).toString()
                } catch (_: Exception) {
                    // Resources unavailable; fall through.
                }
            }
            return packageName
        }
    }

    override fun onListenerConnected() {
        connected = this
    }

    override fun onListenerDisconnected() {
        if (connected === this) {
            connected = null
        }
    }

    override fun onDestroy() {
        if (connected === this) {
            connected = null
        }
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (_: Exception) {
            // Never crash the listener on an unusual notification.
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) {
            return
        }
        rememberApp(sbn)
        val store = CaptureStore.get(this)
        if (!store.watchedPackages().contains(sbn.packageName)) {
            return
        }
        val notification = sbn.notification
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0 ||
            notification.flags and Notification.FLAG_ONGOING_EVENT != 0 ||
            notification.flags and Notification.FLAG_FOREGROUND_SERVICE != 0
        ) {
            return
        }
        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString("\n") { it.toString() }
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: lines
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString()?.trim()
        if (text.isNullOrEmpty() && title.isNullOrEmpty()) {
            return
        }
        val queued = store.append(
            packageName = sbn.packageName,
            appLabel = appLabel(this, sbn.packageName, notification),
            key = sbn.key,
            title = title,
            text = text ?: "",
            postedAt = sbn.postTime,
        )
        if (queued) {
            CaptureStore.onCaptured?.invoke()
        }
    }

    private fun rememberApp(sbn: StatusBarNotification) {
        synchronized(recentApps) {
            if (recentApps.containsKey(sbn.packageName)) {
                recentApps.remove(sbn.packageName)?.let { recentApps[sbn.packageName] = it }
                return
            }
        }
        val label = appLabel(this, sbn.packageName, sbn.notification)
        synchronized(recentApps) {
            recentApps[sbn.packageName] = label
            while (recentApps.size > MAX_RECENT_APPS) {
                recentApps.remove(recentApps.keys.first())
            }
        }
    }

    /** Package -> label of apps that have a notification showing now. */
    fun activeApps(): Map<String, String> {
        val result = LinkedHashMap<String, String>()
        val active = try {
            activeNotifications
        } catch (_: SecurityException) {
            null
        } ?: return result
        for (sbn in active) {
            if (sbn.packageName == packageName || result.containsKey(sbn.packageName)) {
                continue
            }
            result[sbn.packageName] = appLabel(this, sbn.packageName, sbn.notification)
        }
        return result
    }
}
