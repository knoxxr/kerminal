// Opens the app database. The implementation differs by platform (native uses
// the app-private support directory + a one-time migration; web uses IndexedDB
// via drift_flutter), selected by conditional import so `dart:io` never leaks
// into the web build.
export 'db_connection_web.dart'
    if (dart.library.io) 'db_connection_native.dart';
