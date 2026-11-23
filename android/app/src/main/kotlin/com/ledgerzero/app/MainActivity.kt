package com.ledgerzero.app

import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val INSTALL_CHANNEL = "com.ledgerzero.app/install"
    }

    private var appLock: AppLockChannel? = null
    private var review: ReviewChannel? = null
    private var installChannel: MethodChannel? = null
    private var notificationCapture: NotificationCaptureChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Financial data: no screenshots, no screen recording, and a blank
        // thumbnail in the recent-apps overview.
        // The demo build for store screenshots (debuggable, id ending in
        // ".demo", sample data only) is the one exception.
        val demo = packageName.endsWith(".demo") &&
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!demo) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                setRecentsScreenshotEnabled(false)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        appLock = AppLockChannel(this, messenger)
        review = ReviewChannel(this, messenger)
        // The directory that Android never backs up or moves to a new phone
        // (Context.getNoBackupFilesDir): its install marker tells a moved
        // install from the original (lib/services/backup/transferred_install.dart).
        installChannel = MethodChannel(messenger, INSTALL_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "noBackupDirectory" -> result.success(noBackupFilesDir.absolutePath)
                    else -> result.notImplemented()
                }
            }
        }
        notificationCapture = NotificationCaptureChannel(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        appLock?.dispose()
        appLock = null
        review?.dispose()
        review = null
        installChannel?.setMethodCallHandler(null)
        installChannel = null
        notificationCapture?.dispose()
        notificationCapture = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
