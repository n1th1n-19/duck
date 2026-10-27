package org.localsend.localsend_app

import android.content.Context
import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns the single Flutter engine of the app.
 *
 * The engine outlives [MainActivity] so that "Tap to share" can receive while the app
 * is closed: the NFC service starts it headless, and opening the app later attaches the
 * UI to the same engine, so there is never a second server fighting over the port.
 */
class LocalSendApplication : FlutterApplication() {
    companion object {
        private const val ENGINE_ID = "main"

        /// Dart reads this to start the server without waiting for the home page.
        private const val HEADLESS_ARG = "--headless"

        val isEngineRunning: Boolean
            get() = FlutterEngineCache.getInstance().contains(ENGINE_ID)

        /// Returns the running engine, or starts one. Must be called on the main thread.
        fun obtainEngine(context: Context, headless: Boolean): FlutterEngine {
            FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }

            val engine = FlutterEngine(context.applicationContext)
            TapShareChannel.install(context.applicationContext, engine)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
                if (headless) listOf(HEADLESS_ARG) else emptyList(),
            )
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            return engine
        }
    }
}
