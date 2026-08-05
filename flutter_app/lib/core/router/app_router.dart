import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/models/models_screen.dart';
import '../../features/terminal/terminal_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'scaffold_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ScaffoldShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (_, __) => const ChatScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/models', builder: (_, __) => const ModelsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/terminal', builder: (_, __) => const TerminalTabScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())]),
        ],
      ),
    ],
  );
}
