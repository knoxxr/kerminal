import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/host.dart';
import '../../domain/entities/ssh_connection_request.dart';
import '../../presentation/connect/quick_connect_page.dart';
import '../../presentation/hosts/add_edit_host_page.dart';
import '../../presentation/hosts/host_list_page.dart';
import '../../presentation/terminal/terminal_page.dart';

/// App route table.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'hosts',
      builder: (context, state) => const HostListPage(),
    ),
    GoRoute(
      path: '/connect',
      name: 'connect',
      builder: (context, state) =>
          QuickConnectPage(prefill: state.extra as SshConnectionRequest?),
    ),
    GoRoute(
      path: '/host/new',
      name: 'newHost',
      builder: (context, state) => const AddEditHostPage(),
    ),
    GoRoute(
      path: '/host/edit',
      name: 'editHost',
      builder: (context, state) =>
          AddEditHostPage(existing: state.extra as Host?),
    ),
    GoRoute(
      path: '/terminal',
      name: 'terminal',
      builder: (context, state) {
        final request = state.extra as SshConnectionRequest?;
        if (request == null) {
          // Reached without a connection request (e.g. deep link/refresh).
          return const _MissingRequestScreen();
        }
        return TerminalPage(request: request);
      },
    ),
  ],
);

class _MissingRequestScreen extends StatelessWidget {
  const _MissingRequestScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No connection to display.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.goNamed('hosts'),
              child: const Text('Back to hosts'),
            ),
          ],
        ),
      ),
    );
  }
}
