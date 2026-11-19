package dev.sagron.zerotrustfamily

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Starts sharing again after the phone restarts or the app updates, if it
 * was on. Whether to keep going (signed out, paused, left every circle) is
 * Dart's call once the service asks.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (ShareService.wasOn(context)) ShareService.start(context)
            }
        }
    }
}
