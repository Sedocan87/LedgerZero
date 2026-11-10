package com.ledgerzero.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Runs when an update of the app was installed. Android may leave the
 * card notification listener unbound after an update until the next
 * reboot, so that payments are missed until the user happens to open the
 * app; asking for a rebind here brings the listener back at once (only
 * when the user granted notification access).
 */
class PackageReplacedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            CardNotificationListener.requestRebindIfNeeded(context)
        }
    }
}
