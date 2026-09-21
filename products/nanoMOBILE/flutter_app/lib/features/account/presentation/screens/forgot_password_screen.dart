import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';

import '../../application/account_providers.dart';
import '../widgets/nano_glass_field.dart';

/// QUÉ HACE:
/// Pantalla para solicitar el enlace de recuperación de contraseña.
///
/// CÓMO FUNCIONA:
/// Permite enviar un correo con instrucciones seguras. Al completarse,
/// presenta un estado glass limpio de confirmación sin revelar si el usuario existe.
///
/// POR QUÉ:
/// Cumple la regla 6: mitigación de enumeración de usuarios y feedback visual estético.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Ingresa un correo electrónico válido');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (error == null) {
          _isSent = true;
        } else {
          _errorMessage = error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg),
            child: _isSent ? _buildSuccess(colors) : _buildForm(colors),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(NanoColors colors) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.all(NanoSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NanoOwlAvatar(size: 56, state: NanoOwlState.success),
          const SizedBox(height: NanoSpacing.md),
          Text('✓ Revisa tu correo', style: NanoType.headline(colors.primary)),
          const SizedBox(height: 8),
          Text(
            'Hemos enviado un enlace para restablecer tu contraseña. Revisa tu bandeja de entrada o spam.',
            style: NanoType.body(colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NanoSpacing.lg),
          NanoActionButton(
            label: 'Volver al inicio de sesión',
            primary: true,
            expanded: true,
            onPressed: () => context.go('/auth/login'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(NanoColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NanoOwlAvatar(size: 56, state: NanoOwlState.idle),
        const SizedBox(height: NanoSpacing.md),
        Text('Recuperar Acceso', style: NanoType.headline(colors.onSurface)),
        const SizedBox(height: 6),
        Text(
          'Ingresa tu correo y te enviaremos un enlace seguro para restablecer tu contraseña.',
          style: NanoType.caption(colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NanoSpacing.lg),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: NanoType.caption(colors.error)),
          const SizedBox(height: NanoSpacing.sm),
        ],
        NanoGlassField(
          controller: _emailController,
          label: 'Correo electrónico registrado',
          hint: 'nombre@ejemplo.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: NanoSpacing.lg),
        NanoActionButton(
          label: _isLoading ? 'Enviando...' : 'Enviar enlace',
          primary: true,
          expanded: true,
          onPressed: _isLoading ? null : _handleSend,
        ),
      ],
    );
  }
}
