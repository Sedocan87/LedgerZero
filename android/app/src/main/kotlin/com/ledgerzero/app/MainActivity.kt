package com.ledgerzero.app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var notificationCapture: NotificationCaptureChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Financial data: no screenshots, no screen recording, and a blank
        // thumbnail in the recent-apps overview.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BiometricKeyChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        AppLockChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        notificationCapture = NotificationCaptureChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        notificationCapture?.dispose()
        notificationCapture = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
