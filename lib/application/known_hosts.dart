import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

enum HostKeyStatus { unknown, matched, changed }

/// Remembers accepted host-key fingerprints (a `known_hosts` equivalent),
/// persisted in shared preferences as a `host:port -> "SHA256:..."` map.
class KnownHostsService {
  KnownHostsService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'known_hosts';

  Map<String, String> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> _save(Map<String, String> map) =>
      _prefs.setString(_key, jsonEncode(map));

  String _id(String host, int port) => '$host:$port';

  String? fingerprintFor(String host, int port) => _load()[_id(host, port)];

  HostKeyStatus check(String host, int port, String fingerprint) {
    final known = fingerprintFor(host, port);
    if (known == null) return HostKeyStatus.unknown;
    return known == fingerprint ? HostKeyStatus.matched : HostKeyStatus.changed;
  }

  Future<void> trust(String host, int port, String fingerprint) async {
    final map = _load()..[_id(host, port)] = fingerprint;
    await _save(map);
  }

  Future<void> forget(String host, int port) async {
    final map = _load()..remove(_id(host, port));
    await _save(map);
  }
}

final knownHostsProvider = Provider<KnownHostsService>(
  (ref) => KnownHostsService(ref.watch(sharedPreferencesProvider)),
);
