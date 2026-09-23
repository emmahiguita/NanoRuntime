// login_screen.dart — Pantalla oficial de autenticación y acceso a Nano AI.
// QUÉ: Inicio de sesión empresarial y soberano (Credenciales locales, Google y Modo Autónomo).
// CÓMO: Layout reactivo adaptado a orientación con estética Glassmorphism de alta gama.
// POR QUÉ: Garantiza alta fidelidad visual, tono corporativo/ciber-core y cero desbordamientos (<200 líneas).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/adaptive_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../application/account_providers.dart';
import '../widgets/login_auth_header.dart';
import '../widgets/nano_glass_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose(); _password.dispose();
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
    _submit(() => ref.read(authControllerProvider.notifier).login(email: _email.text, password: _password.text));
  }

  void _handleGoogle() => _submit(() => ref.read(authControllerProvider.notifier).continueWithGoogle());

  void _handleAutonomousLocal() {
    final auth = ref.read(authControllerProvider.notifier);
    _submit(() async {
      final loginErr = await auth.login(email: 'operador@nano.local', password: 'nano-local-key');
      if (loginErr != null) {
        return auth.register(email: 'operador@nano.local', password: 'nano-local-key', displayName: 'Operador Soberano');
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final landscape = AdaptiveTheme.isLandscape(context);
    final gap = SizedBox(height: landscape ? 8 : NanoSpacing.md);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: landscape ? NanoSpacing.xxl : NanoSpacing.lg,
              vertical: landscape ? 8 : NanoSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoginAuthHeader(isLandscape: landscape),
                    gap,
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(colors, _errorMessage!),
                      gap,
                    ],
                    _buildFormCard(colors, gap),
                    gap,
                    _buildFooterActions(colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(NanoColors colors, String message) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: colors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(NanoRadius.small),
      border: Border.all(color: colors.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: NanoType.caption(colors.error))),
      ],
    ),
  );

  Widget _buildFormCard(NanoColors colors, Widget gap) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.all(NanoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NanoGlassField(
            controller: _email, label: 'IDENTIFICADOR O CORREO',
            hint: 'operador@nodo-nano.local', prefixIcon: Icons.fingerprint_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'Ingresa un correo o ID válido' : null,
          ),
          gap,
          NanoGlassField(
            controller: _password, label: 'CLAVE DE ACCESO CRIPTOGRÁFICA',
            hint: '••••••••••••', prefixIcon: Icons.lock_outline_rounded,
            isPassword: true, validator: (val) => val == null || val.length < 6 ? 'Mínimo 6 caracteres' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(padding: const EdgeInsets.only(top: 4), visualDensity: VisualDensity.compact),
              onPressed: () => context.push('/auth/forgot-password'),
              child: Text('¿Restablecer credenciales?', style: NanoType.caption(colors.primary)),
            ),
          ),
          const SizedBox(height: 6),
          NanoActionButton(
            label: _isLoading ? 'Autenticando en Nodo...' : 'Autenticar en Nodo Seguro',
            primary: true, expanded: true, icon: Icons.shield_outlined,
            onPressed: _isLoading ? null : _handleLogin,
          ),
          gap,
          _buildDivider(colors),
          gap,
          NanoActionButton(
            label: 'Continuar con Google Workspace',
            primary: false, expanded: true, icon: Icons.g_mobiledata_rounded,
            onPressed: _isLoading ? null : _handleGoogle,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NanoRadius.medium)),
            ),
            icon: Icon(Icons.offline_bolt_outlined, size: 18, color: colors.primary),
            label: Text('Acceso en Modo Autónomo Local (100% Privado)',
                style: NanoType.caption(colors.onSurface).copyWith(fontWeight: FontWeight.w600)),
            onPressed: _isLoading ? null : _handleAutonomousLocal,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(NanoColors colors) => Row(
    children: [
      Expanded(child: Divider(color: colors.outlineVariant.withValues(alpha: 0.5))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('o autenticación federada', style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 11)),
      ),
      Expanded(child: Divider(color: colors.outlineVariant.withValues(alpha: 0.5))),
    ],
  );

  Widget _buildFooterActions(NanoColors colors) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('¿Nuevo en la red Nano? ', style: NanoType.caption(colors.onSurfaceVariant)),
      GestureDetector(
        onTap: () => context.push('/auth/register'),
        child: Text('Crear nuevo nodo', style: NanoType.label(colors.primary).copyWith(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}
