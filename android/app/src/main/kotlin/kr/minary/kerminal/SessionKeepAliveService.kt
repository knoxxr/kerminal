package kr.minary.kerminal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app process alive while SSH sessions are open.
 *
 * Android reclaims backgrounded processes aggressively, and killing the process
 * tears down the live TCP sockets — coming back to the app would show dead
 * terminals (or no tabs at all). A foreground service raises the process
 * priority so the sockets, and the shells on the other end, survive an app
 * switch instead of having to reconnect. It also exempts the process from most
 * Doze network restrictions while it runs.
 *
 * Started/stopped from Dart through the `kerminal/session_keep_alive` channel
 * whenever the number of open sessions crosses zero.
 */
class SessionKeepAliveService : Service() {

    companion object {
        private const val CHANNEL_ID = "session_keep_alive"
        private const val NOTIFICATION_ID = 1001
        private const val EXTRA_SESSIONS = "sessions"

        fun start(context: Context, sessions: Int) {
            val intent = Intent(context, SessionKeepAliveService::class.java)
                .putExtra(EXTRA_SESSIONS, sessions)
            // The caller is always in the foreground (a session just opened),
            // so this is allowed under the Android 12+ background-start limits.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SessionKeepAliveService::class.java))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val sessions = intent?.getIntExtra(EXTRA_SESSIONS, 0) ?: 0
        // The foreground service type comes from the manifest declaration.
        startForeground(NOTIFICATION_ID, buildNotification(sessions))
        // Nothing to resurrect if the process dies anyway: the Dart side owns
        // the session list, so a restarted service would have nothing to keep.
        return START_NOT_STICKY
    }

    /**
     * The user swiped the app away, which destroys the Flutter engine and with
     * it every session — so the notification must not outlive them.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(sessions: Int): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // IMPORTANCE_LOW: no sound, and it stays collapsed in the shade.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SSH 세션 유지",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "열린 SSH 세션의 연결을 유지하는 동안 표시됩니다."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val launch = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(this, 0, launch, flags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val text = if (sessions == 1) {
            "세션 1개의 연결을 유지하고 있습니다"
        } else {
            "세션 ${sessions}개의 연결을 유지하고 있습니다"
        }

        return builder
            .setContentTitle("Kerminal")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}
