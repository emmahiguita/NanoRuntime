import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/models/presentation/screens/models_screen.dart';
import '../../features/terminal/presentation/screens/terminal_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/desktop/presentation/screens/desktop_launch_screen.dart';
import '../../features/desktop/presentation/screens/vnc_screen.dart';
import 'scaffold_shell.dart';

class AppRouter {
  static GoRouter router = _build('/dashboard');

  /// (Re)construye el router. [initialRoute] permite arrancar en /settings
  /// cuando el sistema lanza la app desde Ajustes → Apps → Configuración
  /// (ACTION_APPLICATION_PREFERENCES). Null → dashboard por defecto.
  static void init(String? initialRoute) {
    router = _build(initialRoute ?? '/dashboard');
  }

  static GoRouter _build(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ScaffoldShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (_, __) => _fadeSlide(const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (_, __) => _fadeSlide(const ChatScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/models',
                pageBuilder: (_, __) => _fadeSlide(const ModelsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/terminal',
                pageBuilder: (_, __) => _fadeSlide(const TerminalTabScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, __) => _fadeSlide(const SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      // /desktop → pantalla de lanzamiento (instala + arranca Xvnc + espera TCP)
      GoRoute(
        path: '/desktop',
        pageBuilder: (_, __) =>
            const MaterialPage(child: DesktopLaunchScreen()),
      ),
      // /desktop/vnc → cliente RFB real (requiere el puerto activo; ?port=5901)
      GoRoute(
        path: '/desktop/vnc',
        pageBuilder: (context, state) => MaterialPage(
          child: VncScreen(
            port: int.tryParse(state.uri.queryParameters['port'] ?? '') ?? 5901,
          ),
        ),
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
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}
