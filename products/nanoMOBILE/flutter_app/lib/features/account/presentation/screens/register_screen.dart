import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';
import '../../application/account_providers.dart';
import '../widgets/register_country_picker.dart';
import '../widgets/register_form_fields.dart';

/// QUÉ HACE:
/// Pantalla de registro completa y profesional para Nano Mobile.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  CountryInfo _selectedCountry = kNanoCountries.first;
  bool _acceptTerms = true;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Debes aceptar los Términos y Condiciones para continuar.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullPhone = '${_selectedCountry.dialCode} ${_phoneController.text.trim()}';
    final displayName = '$firstName $lastName'.trim();

    final error = await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: displayName,
          firstName: firstName,
          lastName: lastName,
          phone: fullPhone,
          country: _selectedCountry.name,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      if (error == null) {
        context.go('/auth/verify-email');
      }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: NanoSpacing.lg,
              vertical: NanoSpacing.sm,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: NanoOwlAvatar(size: 52, state: NanoOwlState.idle)),
                  const SizedBox(height: NanoSpacing.sm),
                  Text(
                    'Crear Cuenta Profesional',
                    textAlign: TextAlign.center,
                    style: NanoType.headline(colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configura tu identidad y conecta tu entorno Nano',
                    textAlign: TextAlign.center,
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: NanoSpacing.lg),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(NanoSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(NanoRadius.small),
                        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(_errorMessage!, style: NanoType.caption(colors.error)),
                    ),
                    const SizedBox(height: NanoSpacing.md),
                  ],
                  RegisterFormInputs(
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    phoneController: _phoneController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    selectedCountry: _selectedCountry,
                    onSelectCountry: () {
                      showNanoCountryPicker(
                        context: context,
                        colors: colors,
                        onSelected: (country) => setState(() => _selectedCountry = country),
                      );
                    },
                    acceptTerms: _acceptTerms,
                    onAcceptTermsChanged: (v) => setState(() => _acceptTerms = v ?? false),
                    colors: colors,
                  ),
                  const SizedBox(height: NanoSpacing.lg),
                  NanoActionButton(
                    label: _isLoading
                        ? 'Creando cuenta profesional...'
                        : 'Crear cuenta profesional',
                    primary: true,
                    expanded: true,
                    onPressed: _isLoading ? null : _handleRegister,
                  ),
                  const SizedBox(height: NanoSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
