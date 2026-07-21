import 'package:go_router/go_router.dart';

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
      path: '/terminal/:hostId',
      name: 'terminal',
      builder: (context, state) => TerminalPage(
        hostId: state.pathParameters['hostId']!,
      ),
    ),
  ],
);
