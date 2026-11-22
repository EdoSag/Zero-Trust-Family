package dev.sagron.zerotrustfamily

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager

/**
 * Shows family alerts ("Dana arrived at School") that Dart worked out.
 * Two channels: normal, and a silent one used during quiet hours, so the
 * person can tune each in Android's settings too.
 */
object AlertNotifier {
    private const val CHANNEL = "family_alerts"
    private const val QUIET_CHANNEL = "family_alerts_quiet"
    private const val URGENT_CHANNEL = "family_sos"

    fun post(context: Context, args: Map<*, *>) {
        val id = (args["id"] as? Number)?.toInt() ?: return
        val title = args["title"] as? String ?: return
        val text = args["text"] as? String ?: ""
        val quiet = args["quiet"] == true
        val urgent = args["urgent"] == true
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
        manager.createNotificationChannel(
            NotificationChannel(
                URGENT_CHANNEL,
                args["urgentChannelName"] as? String ?: "SOS and missed check-ins",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                // Rings like an alarm: an SOS must be heard.
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                enableVibration(true)
            },
        )
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(context, 1, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val channel = when {
            urgent -> URGENT_CHANNEL
            quiet -> QUIET_CHANNEL
            else -> CHANNEL
        }
        val notification = Notification.Builder(context, channel)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(args["ongoing"] != true)
            .setOngoing(args["ongoing"] == true)
            .setCategory(if (urgent) Notification.CATEGORY_ALARM else Notification.CATEGORY_STATUS)
            .apply {
                if (open != null) setContentIntent(open)
                // Up to two buttons ("I'm OK", and "Send SOS now" on a
                // crash countdown); each wakes the service with its kind.
                for ((n, suffix) in listOf(0 to "", 1 to "2")) {
                    val label = args["action${suffix}Label"] as? String ?: continue
                    val kind = args["action${suffix}Kind"] as? String ?: continue
                    val intent = Intent(context, ShareService::class.java)
                        .setAction(ShareService.ACTION_ALERT)
                        .putExtra(ShareService.EXTRA_KIND, kind)
                        .putExtra(ShareService.EXTRA_SPACE, args["actionSpace"] as? String)
                        .putExtra(ShareService.EXTRA_NOTIFICATION, id)
                    val pending = PendingIntent.getForegroundService(
                        context,
                        // One request code per button, so they don't replace each other.
                        id * 2 + n,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    addAction(Notification.Action.Builder(null as android.graphics.drawable.Icon?, label, pending).build())
                }
            }
            .build()
        try {
            if (args["ongoing"] == true) notification.flags = notification.flags or Notification.FLAG_INSISTENT
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            // Notifications not allowed: the app shows the event when opened.
        }
    }

    fun cancel(context: Context, id: Int) {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }
}
