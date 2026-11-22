package dev.sagron.zerotrustfamily

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Channel `zt_family/share` between Dart (`ShareChannel`) and [ShareService].
 *
 * Dart calls `start`, `stop`, `poke`, `notify` (a family alert) and
 * `cancel`. The service calls `started`, `fix`, `motion` and `drive` (driving
 * samples); each answer is a map with `stop`, `locate`, `drive`,
 * `intervalMs`, `wakeAt`, `title`, `text` and `channelName`.
 */
object ShareBridge {
    var channel: MethodChannel? = null
        private set

    fun attach(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "zt_family/share").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        ShareService.start(app)
                        result.success(null)
                    }
                    "stop" -> {
                        ShareService.stop(app)
                        result.success(null)
                    }
                    "poke" -> {
                        ShareService.poke(app)
                        result.success(null)
                    }
                    "notify" -> {
                        AlertNotifier.post(app, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                        result.success(null)
                    }
                    "cancel" -> {
                        val id = (call.argument<Number>("id"))?.toInt()
                        if (id != null) AlertNotifier.cancel(app, id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
