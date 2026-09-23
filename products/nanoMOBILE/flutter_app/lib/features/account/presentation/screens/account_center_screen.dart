// account_center_screen.dart — Pantalla estándar de gestión de perfil personal.
// QUÉ HACE: Permite ver y editar fotografía, datos personales, ubicación y contacto del usuario.
// CÓMO FUNCIONA: Orquesta widgets modulares con persistencia local y sincronizable sin métricas de sistema.
// POR QUÉ: Otorga una experiencia humana, limpia y profesional idéntica a apps ejecutivas.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../application/account_providers.dart';
import '../widgets/nano_danger_dialog.dart';
import '../widgets/profile_avatar_header.dart';
import '../widgets/profile_contact_fields.dart';
import '../widgets/profile_location_fields.dart';
import '../widgets/profile_personal_fields.dart';

class AccountCenterScreen extends ConsumerStatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  ConsumerState<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends ConsumerState<AccountCenterScreen> {
  late final TextEditingController _nameCtrl, _usernameCtrl, _bioCtrl;
  late final TextEditingController _countryCtrl, _stateCtrl, _cityCtrl, _addressCtrl;
  late final TextEditingController _phoneCtrl, _emailCtrl;
  String? _photoPath;
  DateTime? _birthDate;
  String _gender = '', _language = 'Español';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(sessionGateProvider).profile, u = ref.read(sessionGateProvider).user;
    _nameCtrl = TextEditingController(text: p.displayName.isNotEmpty ? p.displayName : u.displayName);
    _usernameCtrl = TextEditingController(text: p.username.isNotEmpty ? p.username : '@emmanuel');
    _bioCtrl = TextEditingController(text: p.bio);
    _countryCtrl = TextEditingController(text: p.country.isNotEmpty ? p.country : 'Colombia');
    _stateCtrl = TextEditingController(text: p.stateProvince.isNotEmpty ? p.stateProvince : 'Antioquia');
    _cityCtrl = TextEditingController(text: p.city.isNotEmpty ? p.city : 'Medellín');
    _addressCtrl = TextEditingController(text: p.address);
    _phoneCtrl = TextEditingController(text: p.phone);
    _emailCtrl = TextEditingController(text: p.email.isNotEmpty ? p.email : u.email);
    _photoPath = p.photoUrl;
    _birthDate = p.birthDate;
    _gender = p.gender;
    _language = p.language.isNotEmpty ? p.language : 'Español';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose(); _bioCtrl.dispose();
    _countryCtrl.dispose(); _stateCtrl.dispose(); _cityCtrl.dispose();
    _addressCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NanoRadius.small)),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final p = ref.read(sessionGateProvider).profile;
    final updated = p.copyWith(
      displayName: _nameCtrl.text.trim(), username: _usernameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(), country: _countryCtrl.text.trim(),
      stateProvince: _stateCtrl.text.trim(), city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(), photoUrl: _photoPath,
      birthDate: _birthDate, gender: _gender, language: _language,
    );
    await ref.read(sessionGateProvider.notifier).updateProfile(updated);
    if (mounted) {
      setState(() => _isSaving = false);
      _showSnack('Perfil guardado exitosamente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0, scrolledUnderElevation: 0,
        title: Text('Mi perfil', style: NanoType.headline(colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          ProfileAvatarHeader(
            displayName: _nameCtrl.text,
            username: _usernameCtrl.text,
            photoPath: _photoPath,
            onPhotoChanged: (path) => setState(() => _photoPath = path),
          ),
          const SizedBox(height: 24),
          ProfilePersonalFields(
            nameController: _nameCtrl,
            usernameController: _usernameCtrl,
            bioController: _bioCtrl,
            birthDate: _birthDate,
            gender: _gender,
            onBirthDateChanged: (d) => setState(() => _birthDate = d),
            onGenderChanged: (g) => setState(() => _gender = g),
          ),
          const SizedBox(height: 24),
          ProfileLocationFields(
            countryController: _countryCtrl,
            stateController: _stateCtrl,
            cityController: _cityCtrl,
            addressController: _addressCtrl,
          ),
          const SizedBox(height: 24),
          ProfileContactFields(
            phoneController: _phoneCtrl,
            emailController: _emailCtrl,
            language: _language,
            onLanguageChanged: (l) => setState(() => _language = l),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NanoRadius.medium)),
            ),
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios',
                style: NanoType.title(Colors.white).copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/auth/login');
                },
                icon: Icon(Icons.logout_rounded, size: 16, color: colors.onSurfaceVariant),
                label: Text('Cerrar sesión', style: NanoType.caption(colors.onSurfaceVariant)),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await NanoDangerDialog.show(
                    context: context,
                    title: '¿Eliminar cuenta?',
                    message: 'Esta acción borrará tus datos de perfil permanentemente.',
                    confirmLabel: 'Sí, eliminar',
                  );
                  if (confirmed == true && context.mounted) {
                    await ref.read(authControllerProvider.notifier).deleteAccount();
                    if (context.mounted) context.go('/auth/login');
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                label: Text('Eliminar cuenta', style: NanoType.caption(const Color(0xFFEF4444))),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
