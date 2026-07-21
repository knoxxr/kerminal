import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/host.dart';
import '../../domain/entities/ssh_connection_request.dart';
import '../../presentation/connect/quick_connect_page.dart';
import '../../presentation/hosts/add_edit_host_page.dart';
import '../../presentation/hosts/host_list_page.dart';
import '../../presentation/settings/settings_page.dart';
import '../../presentation/terminal/terminal_tabs_page.dart';

/// Root navigator key — lets non-widget code (e.g. the host-key verifier)
/// surface dialogs without a passed-in [BuildContext].
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// App route table.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
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
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/terminal',
      name: 'terminal',
      builder: (context, state) => const TerminalTabsPage(),
    ),
  ],
);
