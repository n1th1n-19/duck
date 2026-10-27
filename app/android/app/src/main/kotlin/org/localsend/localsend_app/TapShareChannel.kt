package org.localsend.localsend_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

const val CHANNEL = "org.localsend.localsend_app/localsend"

private const val INCOMING_CHANNEL_ID = "incoming"
private const val INCOMING_NOTIFICATION_ID = 7301
private const val RECEIVED_NOTIFICATION_ID = 7302

/**
 * The method channel part that works without an activity, so the engine can run
 * headless (started by a tap while the app is closed). [MainActivity] handles the
 * activity-bound methods and delegates everything else to [handle].
 */
object TapShareChannel {
    /// Wires the channel and the tap callbacks to [engine]. Called again when the activity detaches.
    private var channel: MethodChannel? = null

    fun install(context: Context, engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        this.channel = channel
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

            "tapShareTakePendingSend" -> {
                result.success(TapShareState.pendingSend)
                TapShareState.pendingSend = null
            }

            "tapShareSendResult" -> {
                val alias = call.argument<String>("alias") ?: ""
                val ok = call.argument<Boolean>("ok") ?: false
                TapShareState.onSendResult?.invoke(alias, ok)
                result.success(null)
            }

            "tapShareNotifyIncoming" -> {
                notify(context, INCOMING_NOTIFICATION_ID, call.arguments as String)
                result.success(null)
            }

            "tapShareNotifyReceived" -> {
                val ok = call.argument<Boolean>("ok") ?: true
                TapShareFeedback.vibrate(context, if (ok) TapShareFeedback.Kind.SUCCESS else TapShareFeedback.Kind.FAILURE)
                notify(context, RECEIVED_NOTIFICATION_ID, call.argument<String>("text") ?: "")
                result.success(null)
            }

            "getFileDescriptor" -> getFileDescriptor(context, call, result)

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

    /// Opens a content URI for Rust (hashing and upload). Headless too, e.g. for files from the share sheet.
    private fun getFileDescriptor(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "Missing content URI", null)
            return
        }

        val uri = Uri.parse(uriString)
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) {
            result.error("INVALID_ARGUMENT", "Expected a content:// URI", null)
            return
        }

        try {
            val parcelFileDescriptor = context.contentResolver.openFileDescriptor(uri, "r")
            if (parcelFileDescriptor == null) {
                result.error("OPEN_FAILED", "The content provider did not return a file descriptor", null)
                return
            }

            // Ownership of the detached descriptor is transferred to the caller. It must be
            // closed by Rust (or whichever native consumer receives it) after use.
            parcelFileDescriptor.use {
                result.success(it.detachFd())
            }
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message ?: "Permission denied for content URI", null)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message ?: "Failed to open content URI", null)
        }
    }

    /// Tells Dart a share sheet send is waiting. A Dart side that is still booting picks
    /// it up itself once tap share is initialized (tapShareTakePendingSend).
    fun notifySendPending() {
        channel?.invokeMethod("onTapShareSendPending", null)
    }

    /// Shown while no UI is on screen; tapping it opens the app (and a pending receive page).
    private fun notify(context: Context, id: Int, text: String) {
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
            id,
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
