import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../domain/entities/host.dart';
import '../../domain/entities/ssh_connection_request.dart';

/// Home screen: the list of saved SSH hosts, plus a Quick Connect entry for
/// ad-hoc connections. Full host CRUD and credential storage arrive in Phase 2.
class HostListPage extends ConsumerWidget {
  const HostListPage({super.key});

  SshConnectionRequest _prefillFor(Host host) => SshConnectionRequest(
        host: host.hostname,
        port: host.port,
        username: host.username,
        authKind: host.authMethod == AuthMethod.sshKey
            ? SshAuthKind.key
            : SshAuthKind.password,
        label: host.label,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hosts'),
        actions: [
          IconButton(
            tooltip: 'Quick Connect',
            icon: const Icon(Icons.bolt),
            onPressed: () => context.pushNamed('connect'),
          ),
        ],
      ),
      body: hosts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final host = list[i];
              return ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(host.label),
                subtitle:
                    Text('${host.username}@${host.hostname}:${host.port}'),
                onTap: () =>
                    context.pushNamed('connect', extra: _prefillFor(host)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Phase 2: open the add-host form.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add host — coming in Phase 2')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('No saved hosts yet.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.pushNamed('connect'),
            icon: const Icon(Icons.bolt),
            label: const Text('Quick Connect'),
          ),
        ],
      ),
    );
  }
}
