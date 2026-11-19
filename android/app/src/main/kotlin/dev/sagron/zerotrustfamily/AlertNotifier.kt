package dev.sagron.zerotrustfamily

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context

/**
 * Shows family alerts ("Dana arrived at School") that Dart worked out.
 * Two channels: normal, and a silent one used during quiet hours, so the
 * person can tune each in Android's settings too.
 */
object AlertNotifier {
    private const val CHANNEL = "family_alerts"
    private const val QUIET_CHANNEL = "family_alerts_quiet"

    fun post(context: Context, args: Map<*, *>) {
        val id = (args["id"] as? Number)?.toInt() ?: return
        val title = args["title"] as? String ?: return
        val text = args["text"] as? String ?: ""
        val quiet = args["quiet"] == true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                args["channelName"] as? String ?: "Family alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
        manager.createNotificationChannel(
            NotificationChannel(
                QUIET_CHANNEL,
                args["quietChannelName"] as? String ?: "Family alerts (quiet hours)",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(context, 1, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = Notification.Builder(context, if (quiet) QUIET_CHANNEL else CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .apply { if (open != null) setContentIntent(open) }
            .build()
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            // Notifications not allowed: the app shows the event when opened.
        }
    }
}
