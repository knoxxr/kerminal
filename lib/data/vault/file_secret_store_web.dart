import 'secure_vault.dart';

/// Web stub: there is no macOS file store on the web, so always fall back to
/// the default (web storage) secret store.
SecretStore? macosSecretStore() => null;
