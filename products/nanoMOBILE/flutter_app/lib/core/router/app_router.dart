import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/nano_motion.dart';
import '../theme/nano_transitions.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/models/presentation/screens/models_screen.dart';
import '../../features/terminal/presentation/screens/terminal_hub_screen.dart';
import '../../features/terminal/presentation/screens/terminal_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/linux/presentation/screens/mobile_linux_screen.dart';
import '../../features/desktop/presentation/screens/desktop_launch_screen.dart';
import '../../features/desktop/presentation/screens/vnc_screen.dart';
import '../../features/desktop/presentation/screens/desktop_audit_screen.dart';
import '../../features/automation/presentation/screens/automation_screen.dart';
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
                pageBuilder: (_, __) => _glassMorph(const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (_, __) => _glassMorph(const ChatScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/models',
                pageBuilder: (_, __) => _glassMorph(const ModelsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/terminal',
                pageBuilder: (_, __) => _glassMorph(const TerminalHubScreen()),
              ),
              GoRoute(
                path: '/terminal/shell',
                pageBuilder: (_, state) {
                  // Comando inyectado por la UI: /terminal/shell?cmd=kali%20shell
                  final cmd = state.uri.queryParameters['cmd'];
                  return _glassMorph(TerminalTabScreen(initialCommand: cmd));
                },
              ),
              GoRoute(
                path: '/linux',
                pageBuilder: (_, __) => _glassMorph(const MobileLinuxScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, __) =>
                    _expressiveSlide(const SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      // /desktop → pantalla de lanzamiento (instala + arranca Xvnc + espera TCP)
      GoRoute(
        path: '/desktop',
        pageBuilder: (_, __) => _expressiveSlide(const DesktopLaunchScreen()),
      ),
      // /automation → apartado dedicado (NO vive en Ajustes)
      GoRoute(
        path: '/automation',
        pageBuilder: (_, __) => _expressiveSlide(const AutomationScreen()),
      ),
      GoRoute(
        path: '/desktop/audit',
        pageBuilder: (_, __) => _expressiveSlide(const DesktopAuditScreen()),
      ),
      // /desktop/vnc → cliente RFB real (requiere el puerto activo; ?port=5901)
      GoRoute(
        path: '/desktop/vnc',
        pageBuilder: (context, state) => _expressiveSlide(
          VncScreen(
            port: int.tryParse(state.uri.queryParameters['port'] ?? '') ?? 5901,
          ),
        ),
      ),
    ],
  );

  /// Transición Principal de Navegación (Glass Morph Transition)
  static Page<void> _glassMorph(Widget child) => CustomTransitionPage<void>(
    transitionDuration: NanoMotionDurations.navigation,
    reverseTransitionDuration: NanoMotionDurations.navigation,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return NanoGlassMorphTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
    child: child,
  );

  /// Transición Secundaria (Expressive Slide)
  static Page<void> _expressiveSlide(Widget child) =>
      CustomTransitionPage<void>(
        transitionDuration: NanoMotionDurations.standard,
        reverseTransitionDuration: NanoMotionDurations.standard,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return NanoExpressiveSlideTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: child,
      );
}
