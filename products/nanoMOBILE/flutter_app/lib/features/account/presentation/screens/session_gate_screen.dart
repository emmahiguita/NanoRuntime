import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';
import '../../application/account_providers.dart';
import '../../domain/auth_state.dart';

/// QUÉ HACE:
/// Pantalla guardiana de sesión (Session Gate) para Nano Mobile.
///
/// CÓMO FUNCIONA:
/// Observa reactivamente el [sessionGateProvider]. Mientras se inicializa,
/// muestra el búho Nano en estado `thinking`. Una vez resuelta la sesión:
/// - Si está autenticado (online u offline) → redirige a `/dashboard`.
/// - Si no tiene sesión → redirige a `/auth/login`.
/// - Si requiere verificar email → redirige a `/auth/verify-email`.
///
/// POR QUÉ:
/// Garantiza la regla 2: nunca mostrar la pantalla de Login por un instante si
/// el usuario ya contaba con una sesión válida persistida.
class SessionGateScreen extends ConsumerWidget {
  const SessionGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;

    ref.listen<AuthState>(sessionGateProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated ||
          next.status == AuthStatus.offlineAuthenticated) {
        context.go('/dashboard');
      } else if (next.status == AuthStatus.unauthenticated) {
        context.go('/auth/login');
      } else if (next.status == AuthStatus.emailVerificationRequired) {
        context.go('/auth/verify-email');
      }
    });

    final authState = ref.watch(sessionGateProvider);

    if (authState.status == AuthStatus.accountDisabled) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NanoSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NanoOwlAvatar(size: 64, state: NanoOwlState.error),
                const SizedBox(height: NanoSpacing.lg),
                Text('Cuenta Inhabilitada', style: NanoType.headline(colors.error)),
                const SizedBox(height: 8),
                Text(
                  'Esta cuenta ha sido desactivada. Por favor ponte en contacto con soporte técnico.',
                  style: NanoType.body(colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NanoOwlAvatar(size: 80, state: NanoOwlState.thinking),
            const SizedBox(height: NanoSpacing.lg),
            Text(
              'NANO AI',
              style: NanoType.title(colors.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Inicializando entorno seguro...',
              style: NanoType.caption(colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
