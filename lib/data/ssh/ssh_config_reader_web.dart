/// Web stub: browsers have no filesystem, so there is no config to import.
Future<String?> readSshConfig() async => null;

bool get sshConfigImportSupported => false;
