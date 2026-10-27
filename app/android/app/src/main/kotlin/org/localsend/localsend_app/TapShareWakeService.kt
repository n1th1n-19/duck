package org.localsend.localsend_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log

private const val TAG = "TapShare"
private const val CHANNEL_ID = "tap_share_ready"
private const val NOTIFICATION_ID = 7300

/// How long the process stays awake after a tap. The transfer itself is kept
/// alive by the Dart foreground service (flutter_foreground_task) once it starts.
private const val AWAKE_MS = 90_000L

/**
 * Started by a tap while the app is in the background: boots the Flutter engine
 * headless (which starts the server) and keeps the process from being frozen until
 * the sender's upload request arrives.
 */
class TapShareWakeService : Service() {
    companion object {
        fun start(context: Context) {
            val intent = Intent(context, TapShareWakeService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Android 12+ may refuse a background start; still boot the engine, the
                // system keeps the process alive for a while after the NFC binding.
                Log.w(TAG, "Could not start the wake service, starting the engine directly", e)
                LocalSendApplication.obtainEngine(context, headless = true)
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        LocalSendApplication.obtainEngine(this, headless = true)

        // A second tap restarts the timer.
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ stopSelf() }, AWAKE_MS)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, getString(R.string.tap_share_ready_channel), NotificationManager.IMPORTANCE_LOW)
            )
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return builder
            .setSmallIcon(R.drawable.ic_tap_share)
            .setContentTitle(getString(R.string.app_name_duck))
            .setContentText(getString(R.string.tap_share_ready))
            .build()
    }
}
