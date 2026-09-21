// login_screen.dart — Pantalla oficial de autenticación de Nano AI.
// QUÉ: Inicio de sesión mediante credenciales locales o federadas (Google).
// CÓMO: Layout reactivo adaptado a orientación (portrait y landscape compacto).
//       Valida en tiempo real, reporta errores inline y gestiona estado de carga.
// POR QUÉ: Evita desbordamientos de pantalla en modo horizontal (isLandscape),
//          asegura contraste nítido en modo claro y mantiene menos de 180 líneas.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/adaptive_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';
import '../../application/account_providers.dart';
import '../widgets/nano_glass_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<String?> Function() action) async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final err = await action();
    if (mounted) {
      setState(() { _isLoading = false; _errorMessage = err; });
      if (err == null) context.go('/dashboard');
    }
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authControllerProvider.notifier);
    _submit(() => auth.login(email: _email.text, password: _password.text));
  }

  void _handleGoogle() {
    final auth = ref.read(authControllerProvider.notifier);
    _submit(() => auth.continueWithGoogle());
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final landscape = AdaptiveTheme.isLandscape(context);
    final gap = SizedBox(height: landscape ? 6 : NanoSpacing.md);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: landscape ? NanoSpacing.xl : NanoSpacing.lg,
              vertical: landscape ? 8 : NanoSpacing.md,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabecera compacta adaptable
                  if (!landscape) ...[
                    const NanoOwlAvatar(size: 52, state: NanoOwlState.idle),
                    const SizedBox(height: 6),
                    Text('NANO', style: NanoType.headline(colors.onSurface)),
                    Text('Tu agente personal local-first', style: NanoType.caption(colors.onSurfaceVariant)),
                    const SizedBox(height: NanoSpacing.lg),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const NanoOwlAvatar(size: 32, state: NanoOwlState.idle),
                        const SizedBox(width: 8),
                        Text('NANO', style: NanoType.title(colors.onSurface)),
                        const SizedBox(width: 8),
                        Text('·  Agente local-first', style: NanoType.caption(colors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(NanoRadius.small),
                        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: colors.error, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_errorMessage!, style: NanoType.caption(colors.error))),
                        ],
                      ),
                    ),
                    gap,
                  ],

                  NanoGlassField(
                    controller: _email,
                    label: 'Correo electrónico',
                    hint: 'nombre@ejemplo.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !val.contains('@') ? 'Ingresa un correo válido' : null,
                  ),
                  gap,
                  NanoGlassField(
                    controller: _password,
                    label: 'Contraseña',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    validator: (val) => val == null || val.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => context.push('/auth/forgot-password'),
                      child: Text('¿Olvidaste tu contraseña?', style: NanoType.caption(colors.primary)),
                    ),
                  ),
                  const SizedBox(height: 4),

                  NanoActionButton(
                    label: _isLoading ? 'Iniciando...' : 'Iniciar sesión',
                    primary: true,
                    expanded: true,
                    onPressed: _isLoading ? null : _handleLogin,
                  ),
                  gap,
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('o', style: NanoType.caption(colors.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: colors.outlineVariant)),
                    ],
                  ),
                  gap,
                  NanoActionButton(
                    label: 'Continuar con Google',
                    primary: false,
                    expanded: true,
                    icon: Icons.g_mobiledata_rounded,
                    onPressed: _isLoading ? null : _handleGoogle,
                  ),
                  gap,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿Nuevo en Nano? ', style: NanoType.caption(colors.onSurfaceVariant)),
                      GestureDetector(
                        onTap: () => context.push('/auth/register'),
                        child: Text('Crear cuenta', style: NanoType.label(colors.primary)),
                      ),
                    ],
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
