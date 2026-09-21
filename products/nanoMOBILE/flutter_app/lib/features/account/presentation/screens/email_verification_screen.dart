import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';

import '../../application/account_providers.dart';

/// QUÉ HACE:
/// Pantalla que exige la verificación de correo electrónico.
///
/// CÓMO FUNCIONA:
/// Muestra el email parcialmente ofuscado, un botón para comprobar el estado
/// ("Ya lo verifiqué") y reenvío con temporizador de cooldown de 30 segundos.
///
/// POR QUÉ:
/// Cumple la regla 7: previene registros no validados y abuso de reenvío.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  int _cooldownSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final visible = name.length > 2 ? name.substring(0, 2) : name;
    return '$visible***@${parts[1]}';
  }

  Future<void> _checkVerified() async {
    await ref.read(authControllerProvider.notifier).reloadUser();
    final user = await ref.read(authRepositoryProvider).getCurrentUser();
    if (user != null && user.isEmailVerified && mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    await ref.read(authRepositoryProvider).sendEmailVerification();
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final authState = ref.watch(sessionGateProvider);
    final maskedEmail = _maskEmail(authState.user.email);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg),
            child: NanoOpticalSurface(
              borderRadius: NanoRadius.large,
              padding: const EdgeInsets.all(NanoSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NanoOwlAvatar(size: 64, state: NanoOwlState.listening),
                  const SizedBox(height: NanoSpacing.md),
                  Text('Verifica tu correo', style: NanoType.headline(colors.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                    'Enviamos un correo de confirmación a:\n$maskedEmail',
                    style: NanoType.body(colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: NanoSpacing.xl),
                  NanoActionButton(
                    label: 'Ya lo verifiqué',
                    primary: true,
                    expanded: true,
                    onPressed: _checkVerified,
                  ),
                  const SizedBox(height: NanoSpacing.sm),
                  NanoActionButton(
                    label: _cooldownSeconds > 0
                        ? 'Reenviar en $_cooldownSeconds s'
                        : 'Reenviar correo',
                    primary: false,
                    expanded: true,
                    onPressed: _cooldownSeconds > 0 ? null : _resend,
                  ),
                  const SizedBox(height: NanoSpacing.md),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) context.go('/auth/login');
                    },
                    child: Text(
                      'Cambiar de cuenta / Cerrar sesión',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
