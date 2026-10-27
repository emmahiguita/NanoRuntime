import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/account_providers.dart';
import '../../domain/account_exceptions.dart';
import '../widgets/frost_login_surface.dart';
import '../widgets/login_access_form.dart';
import '../widgets/login_page_layout.dart';

/// Coordina acceso y navegación; delega presentación sin duplicar autenticación.
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Una operación en vuelo; siempre libera la carga, incluso si hay excepción.
  Future<void> _submit(Future<String?> Function() action) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    String? error;
    var cancelled = false;
    try {
      error = await action();
    } on GoogleSignInCancelledException {
      cancelled = true;
    } catch (_) {
      error = 'No se pudo iniciar sesión. Intenta de nuevo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    }
    if (mounted && error == null && !cancelled) context.go('/dashboard');
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    _submit(
      () => ref
          .read(authControllerProvider.notifier)
          .login(email: _email.text, password: _password.text),
    );
  }

  // Una pulsación abre el selector oficial; cancelar no equivale a iniciar sesión.
  void _handleGoogle() => _submit(
    () => ref.read(authControllerProvider.notifier).continueWithGoogle(),
  );

  // Conserva el acceso local existente y sus proveedores de almacenamiento.
  void _handleAutonomousLocal() {
    final auth = ref.read(authControllerProvider.notifier);
    _submit(() async {
      final loginError = await auth.login(
        email: 'operador@nano.local',
        password: 'nano-local-key',
      );
      if (loginError != null) {
        return auth.register(
          email: 'operador@nano.local',
          password: 'nano-local-key',
          displayName: 'Operador Soberano',
        );
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) => FrostLoginSurface(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LoginPageLayout(
          form: Form(
            key: _formKey,
            child: LoginAccessForm(
              email: _email,
              password: _password,
              busy: _isLoading,
              error: _errorMessage,
              onLogin: _handleLogin,
              onGoogle: _handleGoogle,
              onLocal: _handleAutonomousLocal,
              onForgot: () => context.push('/auth/forgot-password'),
            ),
          ),
          // Footer estilo iOS con tipografía limpia y sin subrayados.
          footer: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¿No tienes cuenta? ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.none,
                  ),
                ),
                GestureDetector(
                  onTap: _isLoading ? null : () => context.push('/auth/register'),
                  child: Text(
                    'Crear cuenta',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.none,
                    ),
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
