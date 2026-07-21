import 'package:flutter/material.dart';

import '../../application/known_hosts.dart';
import '../../core/router/app_router.dart';
import '../../data/ssh/ssh_service.dart';

/// Builds a [HostKeyVerifier] that checks the fingerprint against
/// [KnownHostsService] and prompts the user (via the root navigator) when the
/// host is new or its key has changed. Replaces trust-on-first-use.
HostKeyVerifier buildHostKeyVerifier(KnownHostsService knownHosts) {
  return (host, port, keyType, fingerprint) async {
    final status = knownHosts.check(host, port, fingerprint);
    if (status == HostKeyStatus.matched) return true;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return false;

    final changed = status == HostKeyStatus.changed;
    final trusted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: Icon(changed ? Icons.warning_amber : Icons.verified_user),
            title: Text(changed ? 'Host key CHANGED' : 'Unknown host'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (changed)
                  const Text(
                    'The host key differs from the one you trusted before. '
                    'This could indicate a man-in-the-middle attack.\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                Text('$host:$port'),
                const SizedBox(height: 8),
                Text('Key type: $keyType'),
                const SizedBox(height: 4),
                SelectableText(
                  fingerprint,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(changed ? 'Trust anyway' : 'Trust'),
              ),
            ],
          ),
        ) ??
        false;

    if (trusted) {
      await knownHosts.trust(host, port, fingerprint);
    }
    return trusted;
  };
}
