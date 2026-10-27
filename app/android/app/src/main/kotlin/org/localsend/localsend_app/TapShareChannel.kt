package org.localsend.localsend_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

const val CHANNEL = "org.localsend.localsend_app/localsend"

private const val INCOMING_CHANNEL_ID = "incoming"
private const val INCOMING_NOTIFICATION_ID = 7301

/**
 * The method channel part that works without an activity, so the engine can run
 * headless (started by a tap while the app is closed). [MainActivity] handles the
 * activity-bound methods and delegates everything else to [handle].
 */
object TapShareChannel {
    /// Wires the channel and the tap callbacks to [engine]. Called again when the activity detaches.
    fun install(context: Context, engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        TapShareState.onTapped = { fingerprint -> channel.invokeMethod("onTapShareTapped", fingerprint) }
        TapShareState.onEnabledChanged = { enabled -> channel.invokeMethod("onTapShareEnabledChanged", enabled) }
        channel.setMethodCallHandler { call, result -> handle(context, call, result) }
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "tapShareGetState" -> result.success(
                mapOf(
                    "available" to TapShareState.isNfcAvailable(context),
                    "enabled" to TapShareState.isEnabled(context),
                    "autoAccept" to TapShareState.isAutoAccept(context),
                )
            )

            "tapShareSetEnabled" -> {
                TapShareState.setEnabled(context, call.arguments as Boolean)
                result.success(null)
            }

            "tapShareSetAutoAccept" -> {
                TapShareState.setAutoAccept(context, call.arguments as Boolean)
                result.success(null)
            }

            "tapShareSetIdentity" -> {
                TapShareState.setIdentity(context, call.arguments as String?)
                result.success(null)
            }

            "tapShareConsumeTap" -> result.success(TapShareState.consumeTap(call.arguments as String))

            // The reader needs an activity; without one this phone can only receive.
            "tapShareSetSender" -> result.success(null)

            "tapShareNotifyIncoming" -> {
                notifyIncoming(context, call.arguments as String)
                result.success(null)
            }

            "getDownloadsDirectory" -> result.success(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath
            )

            "isAnimationsEnabled" -> result.success(
                Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1.0f) != 0.0f
            )

            // Asking needs an activity; headless we can only report the state.
            "requestLocalNetworkPermission" -> result.success(MainActivity.hasLocalNetworkPermission(context))

            else -> result.notImplemented()
        }
    }

    /// A request arrived while no UI is shown: tapping the notification opens the receive page.
    private fun notifyIncoming(context: Context, text: String) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(INCOMING_CHANNEL_ID, context.getString(R.string.tap_share_incoming_channel), NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, INCOMING_CHANNEL_ID) else Notification.Builder(context)
        manager.notify(
            INCOMING_NOTIFICATION_ID,
            builder
                .setSmallIcon(R.drawable.ic_tap_share)
                .setContentTitle(context.getString(R.string.app_name_duck))
                .setContentText(text)
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }
}
