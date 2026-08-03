package kr.minary.kerminal

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "kerminal/session_keep_alive"
        const val NOTIFICATION_PERMISSION_REQUEST = 1002
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sessions = call.argument<Int>("sessions") ?: 0
                        ensureNotificationPermission()
                        SessionKeepAliveService.start(this, sessions)
                        result.success(true)
                    }
                    "stop" -> {
                        SessionKeepAliveService.stop(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * On Android 13+ the keep-alive notification is only *displayed* when
     * POST_NOTIFICATIONS is granted; the service runs either way. Asked once,
     * without handling the answer, since denial costs visibility only.
     */
    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }
}
