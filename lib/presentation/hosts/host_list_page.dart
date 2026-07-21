import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';

/// Home screen: the list of saved SSH hosts. Full CRUD and grouping arrive in
/// Phase 2; this establishes the data-bound scaffold.
class HostListPage extends ConsumerWidget {
  const HostListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hosts')),
      body: hosts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No hosts yet. Add one with the + button.'),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final host = list[i];
              return ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(host.label),
                subtitle: Text('${host.username}@${host.hostname}:${host.port}'),
                onTap: () => context.goNamed(
                  'terminal',
                  pathParameters: {'hostId': host.id},
                ),
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
