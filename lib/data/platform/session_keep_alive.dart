import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks the platform to keep the app process alive while sessions are open.
///
/// Android only. Backgrounding the app normally lets the system reclaim the
/// process, which kills the live SSH sockets — the user comes back to dead
/// terminals. A foreground service (see `SessionKeepAliveService.kt`) holds the
/// process so the sessions genuinely survive an app switch rather than having to
/// reconnect.
///
/// iOS suspends the process no matter what, so there is nothing to call there;
/// those sessions still rely on the reconnect-on-resume path in
/// `SshTerminalController.ensureAlive`.
class SessionKeepAlive {
  const SessionKeepAlive._();

  static const _channel = MethodChannel('kerminal/session_keep_alive');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Number of sessions the service last advertised, so an unchanged count
  /// doesn't re-post the notification on every tab change.
  static int _advertised = 0;

  /// Clears any keep-alive left over from a previous run of the Dart isolate.
  ///
  /// The service can outlive the isolate (e.g. Android destroys the activity but
  /// keeps the process). A fresh isolate starts with no sessions, so without an
  /// unconditional stop the orphaned notification would linger — [sync] alone
  /// would see 0 == 0 and skip the call. Called once at app start.
  static Future<void> reset() {
    _advertised = 0;
    return _invoke('stop', null);
  }

  /// Starts, updates or stops the keep-alive to match [sessionCount].
  static Future<void> sync(int sessionCount) {
    if (sessionCount == _advertised) return Future<void>.value();
    _advertised = sessionCount;
    return sessionCount > 0
        ? _invoke('start', {'sessions': sessionCount})
        : _invoke('stop', null);
  }

  static Future<void> _invoke(String method, Map<String, Object?>? args) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      // Best effort: losing the keep-alive degrades to reconnect-on-resume,
      // which must never take the app down with it.
      debugPrint('session keep-alive $method failed: ${e.message}');
    } on MissingPluginException {
      // Host app without the platform side (e.g. an older build).
    }
  }
}
