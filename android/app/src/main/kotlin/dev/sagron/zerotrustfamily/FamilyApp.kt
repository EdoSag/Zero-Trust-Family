package dev.sagron.zerotrustfamily

import android.app.Application
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns the app's one Flutter engine, so the screen and the location sharing
 * service run the same Dart code with the same signed-in Supabase client.
 *
 * Two engines would each refresh the account's session, and the first
 * refresh makes the other's refresh token stale, signing it out. With one
 * engine there is one client. The activity attaches to this engine and
 * leaves it running when it closes; [ShareService] keeps the process alive
 * while sharing.
 */
class FamilyApp : Application() {
    companion object {
        const val ENGINE_ID = "family"

        /** The running engine, started on first use. Main thread only. */
        fun engine(context: Context): FlutterEngine {
            FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
            val app = context.applicationContext
            val engine = FlutterEngine(app)
            // Listen before Dart starts, so its first calls find the bridge.
            ShareBridge.attach(app, engine)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            return engine
        }
    }
}
