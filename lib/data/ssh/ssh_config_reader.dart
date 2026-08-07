// Reads ~/.ssh/config on desktop; the web build gets a stub that reports the
// feature as unavailable.
export 'ssh_config_reader_web.dart'
    if (dart.library.io) 'ssh_config_reader_io.dart';
