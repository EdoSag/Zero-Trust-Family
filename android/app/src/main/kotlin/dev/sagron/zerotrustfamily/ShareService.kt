package dev.sagron.zerotrustfamily

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.TriggerEvent
import android.hardware.TriggerEventListener
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.LocationRequest
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Shares this phone's location with its family circles while the phone is
 * locked, as a foreground service of type location with its notification
 * always showing.
 *
 * The service only measures. Every position goes to Dart (`ShareEngine`),
 * which encrypts it for each circle, uploads it and answers how long to
 * wait for the next one: every 15 minutes while still, faster while moving
 * or driving, every 10 seconds while sharing live. The significant motion
 * sensor (a hardware trigger that costs next to nothing) wakes the schedule
 * up when a still phone starts moving.
 */
class ShareService : Service(), LocationListener {
    companion object {
        private const val TAG = "ZtFamilyShare"
        private const val CHANNEL_ID = "family_sharing"
        private const val NOTIFICATION_ID = 41
        private const val PREFS = "zt_family_share"
        private const val KEY_ON = "on"
        private const val KEY_TITLE = "title"
        private const val KEY_TEXT = "text"
        private const val KEY_CHANNEL = "channel"
        private const val ACTION_POKE = "poke"

        /** A button on a family alert ("I'm OK"). */
        const val ACTION_ALERT = "alert"
        const val EXTRA_KIND = "kind"
        const val EXTRA_SPACE = "space"
        const val EXTRA_NOTIFICATION = "notification"
        private const val DEFAULT_INTERVAL_MS = 15 * 60 * 1000L

        /** Waits this long to retry when Dart isn't listening yet. */
        private const val RETRY_MS = 3_000L
        private const val MAX_RETRIES = 20

        /** Sharing was on when the phone last ran it (restart after boot). */
        fun wasOn(context: Context): Boolean =
            prefs(context).getBoolean(KEY_ON, false)

        fun start(context: Context) {
            prefs(context).edit().putBoolean(KEY_ON, true).apply()
            val intent = Intent(context, ShareService::class.java)
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                // Android refuses a location service started from the
                // background without "Allow all the time". The next start
                // from the open app tries again.
                Log.w(TAG, "start refused", e)
            }
        }

        fun stop(context: Context) {
            prefs(context).edit().putBoolean(KEY_ON, false).apply()
            context.stopService(Intent(context, ShareService::class.java))
        }

        /** Takes a position now (after resume, joining a circle, going live),
     *  and asks Dart again what to do. */
        fun poke(context: Context) {
            if (!wasOn(context)) return
            val intent = Intent(context, ShareService::class.java).setAction(ACTION_POKE)
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                Log.w(TAG, "poke refused", e)
            }
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    private val main = Handler(Looper.getMainLooper())
    private lateinit var locations: LocationManager
    private var sensors: SensorManager? = null
    private var motionSensor: Sensor? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var intervalMs = DEFAULT_INTERVAL_MS
    private var listening = false
    private var stopped = false

    /** False while only alerts run (not sharing): no positions taken. */
    private var locate = true

    /** Alerts only: wake Dart now and then to look for new alerts. */
    private val alertsTick = Runnable { ask("started", emptyMap()) }

    private val motion = object : TriggerEventListener() {
        override fun onTrigger(event: TriggerEvent?) {
            // One-shot: it is armed again after Dart answers.
            ask("motion", emptyMap())
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        locations = getSystemService(LOCATION_SERVICE) as LocationManager
        sensors = getSystemService(SENSOR_SERVICE) as? SensorManager
        motionSensor = sensors?.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)
        val power = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ztfamily:share").apply {
            setReferenceCounted(false)
        }
        // Starts Dart if the service started the app (after a restart).
        FamilyApp.engine(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!showNotification()) {
            stopSelf()
            return START_NOT_STICKY
        }
        stopped = false
        if (intent?.action == ACTION_ALERT) {
            val kind = intent.getStringExtra(EXTRA_KIND)
            val id = intent.getIntExtra(EXTRA_NOTIFICATION, 0)
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
            when (kind) {
                "checkin" -> ask("checkin", mapOf("spaceId" to intent.getStringExtra(EXTRA_SPACE)))
                "timerOk" -> ask("timerOk", emptyMap())
            }
        } else if (intent?.action == ACTION_POKE) {
            if (locate) {
                listen(force = true)
                now()
            } else {
                ask("started", emptyMap())
            }
        } else if (!listening) {
            ask("started", emptyMap())
            if (locate) now()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopped = true
        stopListening()
        motionSensor?.let { sensors?.cancelTriggerSensor(motion, it) }
        main.removeCallbacksAndMessages(null)
        releaseWake()
        super.onDestroy()
    }

    // --- Notification ---------------------------------------------------

    private fun notification(): Notification {
        val p = prefs(this)
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channelName = p.getString(KEY_CHANNEL, null) ?: "Location sharing"
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
            },
        )
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(p.getString(KEY_TITLE, null) ?: "ZT Family")
            .setContentText(p.getString(KEY_TEXT, null) ?: "")
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .apply {
                if (open != null) setContentIntent(open)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                }
            }
            .build()
    }

    /** False when Android won't let the service run (no location permission). */
    private fun showNotification(): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification())
        }
        true
    } catch (e: Exception) {
        Log.w(TAG, "foreground refused", e)
        false
    }

    // --- Positions ------------------------------------------------------

    private fun provider(): String? {
        val enabled = locations.getProviders(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            LocationManager.FUSED_PROVIDER in enabled
        ) {
            return LocationManager.FUSED_PROVIDER
        }
        // Without the fused provider: the network's rough position while
        // still, satellites when moving.
        val still = intervalMs >= 5 * 60 * 1000L
        val order = if (still) {
            listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
        } else {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        }
        return order.firstOrNull { it in enabled }
    }

    private val recheck = Runnable { listen(force = true) }

    private fun listen(force: Boolean = false) {
        if (listening && !force) return
        stopListening()
        main.removeCallbacks(recheck)
        val provider = provider()
        if (provider == null) {
            // Location is off on the phone: look again on the next interval.
            main.postDelayed(recheck, intervalMs)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val quality = if (intervalMs >= 5 * 60 * 1000L) {
                    LocationRequest.QUALITY_BALANCED_POWER_ACCURACY
                } else {
                    LocationRequest.QUALITY_HIGH_ACCURACY
                }
                val request = LocationRequest.Builder(intervalMs)
                    .setQuality(quality)
                    .setMinUpdateIntervalMillis(intervalMs)
                    .build()
                locations.requestLocationUpdates(provider, request, mainExecutor, this)
            } else {
                @Suppress("DEPRECATION")
                locations.requestLocationUpdates(provider, intervalMs, 0f, this, Looper.getMainLooper())
            }
            listening = true
        } catch (e: SecurityException) {
            // Location permission taken away: the card in the app says so.
            Log.w(TAG, "no location permission", e)
            main.postDelayed(recheck, intervalMs)
        }
    }

    /** One position right away, on top of the schedule. */
    private fun now() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val provider = provider() ?: return
        try {
            locations.getCurrentLocation(provider, null, mainExecutor) { location ->
                if (location != null) onLocationChanged(location)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "no location permission", e)
        }
    }

    private fun stopListening() {
        if (!listening) return
        locations.removeUpdates(this)
        listening = false
    }

    override fun onLocationChanged(location: Location) {
        val args = status().toMutableMap()
        args["lat"] = location.latitude
        args["lng"] = location.longitude
        args["at"] = location.time
        if (location.hasAccuracy()) args["accuracy"] = location.accuracy.toDouble()
        if (location.hasSpeed()) args["speed"] = location.speed.toDouble()
        if (location.hasBearing()) args["heading"] = location.bearing.toDouble()
        ask("fix", args)
    }

    @Deprecated("Needed below API 30")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    private fun status(): Map<String, Any?> {
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val plugged = battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val power = getSystemService(POWER_SERVICE) as PowerManager
        return mapOf(
            "battery" to if (level >= 0 && scale > 0) level * 100 / scale else null,
            "charging" to (plugged != 0),
            "powerSave" to power.isPowerSaveMode,
        )
    }

    // --- Dart -----------------------------------------------------------

    private fun holdWake() {
        // Long enough to encrypt and upload; let go when Dart answers.
        wakeLock?.acquire(60_000L)
    }

    private fun releaseWake() {
        wakeLock?.let { if (it.isHeld) it.release() }
    }

    private fun ask(method: String, args: Map<String, Any?>, attempt: Int = 0) {
        if (stopped) return
        holdWake()
        val channel = ShareBridge.channel
        if (channel == null) {
            retry(method, args, attempt)
            return
        }
        channel.invokeMethod(method, args, object : MethodChannel.Result {
            override fun success(result: Any?) {
                apply(result as? Map<*, *>)
                releaseWake()
            }

            override fun error(code: String, message: String?, details: Any?) {
                Log.w(TAG, "$method failed: $code $message")
                retry(method, args, attempt)
            }

            override fun notImplemented() {
                // Dart hasn't started listening yet (the app is starting).
                retry(method, args, attempt)
            }
        })
    }

    private fun retry(method: String, args: Map<String, Any?>, attempt: Int) {
        if (attempt >= MAX_RETRIES) {
            releaseWake()
            // Keep the schedule going even so.
            listen()
            arm()
            return
        }
        main.postDelayed({ ask(method, args, attempt + 1) }, RETRY_MS)
    }

    private fun apply(answer: Map<*, *>?) {
        if (stopped) return
        if (answer == null) {
            listen()
            arm()
            return
        }
        if (answer["stop"] == true) {
            prefs(this).edit().putBoolean(KEY_ON, false).apply()
            finish()
            return
        }
        val title = answer["title"] as? String
        val text = answer["text"] as? String
        val channelName = answer["channelName"] as? String
        val p = prefs(this)
        if (title != p.getString(KEY_TITLE, null) ||
            text != p.getString(KEY_TEXT, null) ||
            channelName != p.getString(KEY_CHANNEL, null)
        ) {
            p.edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_TEXT, text)
                .putString(KEY_CHANNEL, channelName)
                .apply()
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification())
        }
        val next = (answer["intervalMs"] as? Number)?.toLong()?.coerceIn(5_000L, 60 * 60 * 1000L)
            ?: DEFAULT_INTERVAL_MS
        main.removeCallbacks(alertsTick)
        scheduleWake((answer["wakeAt"] as? Number)?.toLong())
        locate = answer["locate"] != false
        if (!locate) {
            // Alerts only: no location, no motion sensor.
            intervalMs = next
            stopListening()
            main.removeCallbacks(recheck)
            motionSensor?.let { sensors?.cancelTriggerSensor(motion, it) }
            main.postDelayed(alertsTick, intervalMs)
            return
        }
        if (next != intervalMs || !listening) {
            intervalMs = next
            listen(force = true)
        }
        arm()
    }

    /**
     * Wakes the service at [at] (a safety timer's reminder or deadline),
     * also in Doze. Inexact by a few minutes, which needs no special
     * permission; null cancels.
     */
    private fun scheduleWake(at: Long?) {
        val alarms = getSystemService(ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ShareService::class.java).setAction(ACTION_POKE)
        val pending = PendingIntent.getForegroundService(
            this,
            7,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (at == null) {
            alarms.cancel(pending)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    /** Waits for the phone to start moving (only matters while still). */
    private fun arm() {
        val sensor = motionSensor ?: return
        sensors?.cancelTriggerSensor(motion, sensor)
        if (intervalMs >= 5 * 60 * 1000L) sensors?.requestTriggerSensor(motion, sensor)
    }

    private fun finish() {
        stopped = true
        stopListening()
        motionSensor?.let { sensors?.cancelTriggerSensor(motion, it) }
        releaseWake()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
