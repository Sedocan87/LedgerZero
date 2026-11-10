package com.ledgerzero.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play's In-App Review API and the app's Play Store page
 * (lib/services/review/review_service.dart). Play decides whether the rating
 * dialog really appears and never tells the app what the user did.
 */
class ReviewChannel(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "com.ledgerzero.app/review"
        private const val PLAY_STORE = "com.android.vending"
    }

    private val manager by lazy { ReviewManagerFactory.create(activity) }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(playStoreInstalled())
                "requestReview" -> requestReview(result)
                "openStoreListing" -> result.success(openStoreListing())
                else -> result.notImplemented()
            }
        }
    }

    private fun playStoreInstalled(): Boolean = try {
        activity.packageManager.getPackageInfo(PLAY_STORE, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun requestReview(result: MethodChannel.Result) {
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (!request.isSuccessful) {
                result.error("unavailable", request.exception?.message, null)
                return@addOnCompleteListener
            }
            manager.launchReviewFlow(activity, request.result)
                .addOnCompleteListener { result.success(null) }
        }
    }

    private fun openStoreListing(): Boolean {
        val id = activity.packageName
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id"))
            .setPackage(PLAY_STORE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            activity.startActivity(market)
            true
        } catch (_: ActivityNotFoundException) {
            try {
                activity.startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("https://play.google.com/store/apps/details?id=$id"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                true
            } catch (_: ActivityNotFoundException) {
                false
            }
        }
    }
}
