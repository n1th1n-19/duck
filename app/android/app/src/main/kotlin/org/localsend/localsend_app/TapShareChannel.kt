package org.localsend.localsend_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.media.ThumbnailUtils
import android.net.Uri
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Size
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

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
            "tapShareSetSender" -> {
                TapShareState.setSender(call.arguments as String?)
                result.success(null)
            }

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

            "tapShareIsNfcOn" -> result.success(TapShareState.isNfcOn(context))

            "tapShareOpenNfcSettings" -> {
                context.startActivity(Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }

            "tapShareRequestTile" -> {
                // Android 13+ asks the user to add the tile; older versions need it added by hand.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    result.success(false)
                } else {
                    context.getSystemService(StatusBarManager::class.java).requestAddTileService(
                        ComponentName(context, TapShareTileService::class.java),
                        context.getString(R.string.tap_share_tile_label),
                        Icon.createWithResource(context, R.drawable.ic_tap_share),
                        context.mainExecutor,
                    ) { code ->
                        result.success(
                            code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED ||
                                code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED
                        )
                    }
                }
            }

            "tapShareGetAntenna" -> {
                // Android 14+ knows where the NFC antenna sits (mm, origin bottom-left, seen from the screen).
                val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    NfcAdapter.getDefaultAdapter(context)?.nfcAntennaInfo
                } else {
                    null
                }
                result.success(
                    info?.takeIf { it.deviceWidth > 0 && it.deviceHeight > 0 }?.let {
                        mapOf(
                            "width" to it.deviceWidth,
                            "height" to it.deviceHeight,
                            "foldable" to it.isDeviceFoldable,
                            "antennas" to it.availableNfcAntennas.map { a -> listOf(a.locationX, a.locationY) },
                        )
                    }
                )
            }

            "tapShareSendProgress" -> {
                TapShareState.onSendProgress?.invoke(
                    call.argument<String>("sessionId") ?: "",
                    call.argument<String>("alias") ?: "",
                    call.argument<Number>("sent")?.toLong() ?: 0,
                    call.argument<Number>("total")?.toLong() ?: 0,
                )
                result.success(null)
            }

            "tapShareNotifyIncoming" -> {
                notify(context, INCOMING_NOTIFICATION_ID, call.arguments as String)
                result.success(null)
            }

            "tapShareNotifyReceived" -> {
                val ok = call.argument<Boolean>("ok") ?: true
                val text = call.argument<String>("text") ?: ""
                TapShareFeedback.vibrate(context, if (ok) TapShareFeedback.Kind.SUCCESS else TapShareFeedback.Kind.FAILURE)
                // Resolving the file may hit MediaStore / the media scanner: off the main thread.
                Thread {
                    val file = ReceivedFileResolver.resolve(context, call.argument<String>("path"), call.argument<String>("name"), call.argument<Boolean>("gallery") ?: false)
                    notify(context, RECEIVED_NOTIFICATION_ID, text, file)
                }.start()
                result.success(null)
            }

            "resolveReceivedFile" -> {
                // MediaStore / media scanner: off the main thread, answered on it.
                Thread {
                    val uri = ReceivedFileResolver.resolve(context, call.argument<String>("path"), call.argument<String>("name"), call.argument<Boolean>("gallery") ?: false)
                    mainHandler.post { result.success(uri?.toString()) }
                }.start()
            }

            "loadThumbnail" -> {
                val source = call.argument<String>("source") ?: ""
                val video = call.argument<Boolean>("video") ?: false
                val px = call.argument<Int>("size") ?: 192
                Thread {
                    val bytes = loadThumbnail(context, source, video, px)
                    mainHandler.post { result.success(bytes) }
                }.start()
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

    private val mainHandler = Handler(Looper.getMainLooper())

    /// JPEG preview of an image or video (content URI or file path), or null. Android 10+.
    private fun loadThumbnail(context: Context, source: String, video: Boolean, px: Int): ByteArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        return try {
            val size = Size(px, px)
            val bitmap = when {
                source.startsWith("content://") -> context.contentResolver.loadThumbnail(Uri.parse(source), size, null)
                video -> ThumbnailUtils.createVideoThumbnail(File(source), size, null)
                else -> ThumbnailUtils.createImageThumbnail(File(source), size, null)
            }
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                out.toByteArray()
            }
        } catch (e: Exception) {
            null
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

    /// Opens the progress page of a running share sheet send in the app.
    fun openSession(sessionId: String) {
        channel?.invokeMethod("onTapShareOpenSession", sessionId)
    }

    /// Shown while no UI is on screen; tapping it opens the app (and a pending receive page).
    /// [open]: content URI to view when tapped; null opens the app.
    private fun notify(context: Context, id: Int, text: String, open: Uri? = null) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(INCOMING_CHANNEL_ID, context.getString(R.string.tap_share_incoming_channel), NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val target = if (open != null) {
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(open, context.contentResolver.getType(open) ?: "*/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        } else {
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val tap = PendingIntent.getActivity(context, id, target, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, INCOMING_CHANNEL_ID) else Notification.Builder(context)
        manager.notify(
            id,
            builder
                .setSmallIcon(R.drawable.ic_tap_share)
                .setContentTitle(context.getString(R.string.app_name_duck))
                .setContentText(text)
                .setContentIntent(tap)
                .setAutoCancel(true)
                .build(),
        )
    }
}
