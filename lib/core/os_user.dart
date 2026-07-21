// Resolves the current OS username, used as the default when the user leaves
// the account field blank (mirrors the `ssh` CLI). Web/unsupported platforms
// return an empty string via the conditional import.
export 'os_user_web.dart' if (dart.library.io) 'os_user_io.dart';
