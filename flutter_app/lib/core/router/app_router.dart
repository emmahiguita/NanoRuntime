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
          StatefulShellBranch(routes: [GoRoute(path: '/dashboard', pageBuilder: (_, __) => _fadeSlide(const DashboardScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/chat', pageBuilder: (_, __) => _fadeSlide(const ChatScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/models', pageBuilder: (_, __) => _fadeSlide(const ModelsScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/terminal', pageBuilder: (_, __) => _fadeSlide(const TerminalTabScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', pageBuilder: (_, __) => _fadeSlide(const SettingsScreen()))]),
        ],
      ),
    ],
  );

  /// Transición rápida por pestaña: fade + slide-up sutil y muy ágil.
  /// Corta (~180ms) y con curva easeOutCubic para que se sienta vivaz,
  /// no flotante. El indexedStack conserva el estado de cada pestaña.
  static Page<void> _fadeSlide(Widget child) => CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}
