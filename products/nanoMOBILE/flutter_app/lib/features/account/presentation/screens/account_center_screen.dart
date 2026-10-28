import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/account_providers.dart';
import '../controllers/profile_editor_draft.dart';
import '../controllers/profile_media_picker.dart';
import '../widgets/profile_form_sections.dart';
import '../widgets/profile_social_cover.dart';

/// Pantalla de perfil profesional completo con estética iOS Frosted Glass.
///
/// - QUÉ HACE: Centraliza la visualización y edición del perfil del usuario soberano.
/// - CÓMO FUNCIONA: Gestiona un borrador reactivo ([ProfileEditorDraft]) y delega
///   el guardado único a la acción en la barra de navegación superior.
/// - POR QUÉ: Sigue el patrón canónico de Apple iOS, eliminando botones redundantes.
class AccountCenterScreen extends ConsumerStatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  ConsumerState<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends ConsumerState<AccountCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileEditorDraft _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionGateProvider);
    _draft = ProfileEditorDraft(session.profile, session.user);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final profile = ref.read(sessionGateProvider).profile;
      await ref.read(sessionGateProvider.notifier).updateProfile(_draft.applyTo(profile));
      if (mounted) _notify('Perfil profesional guardado exitosamente.');
    } catch (e) {
      if (mounted) _notify('No se pudo guardar el perfil: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickMedia({required bool isAvatar}) async {
    final result = await ProfileMediaPicker.pickImage(
      context: context,
      title: isAvatar ? 'avatar' : 'portada',
      hasExisting: (isAvatar ? _draft.photoPath : _draft.coverPath)?.isNotEmpty ?? false,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isAvatar) {
        _draft.photoPath = result.isEmpty ? null : result;
      } else {
        _draft.coverPath = result.isEmpty ? null : result;
      }
    });
    final profile = ref.read(sessionGateProvider).profile;
    await ref.read(sessionGateProvider.notifier).updateProfile(_draft.applyTo(profile));
    if (mounted) _notify(result.isEmpty ? 'Imagen eliminada.' : 'Imagen actualizada.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final session = ref.watch(sessionGateProvider);
    final profile = session.profile;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mi perfil',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: colors.onSurface,
          ),
        ),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _save,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _saving
                  ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                  : Text(
                      'Guardar',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15, color: colors.primary),
                    ),
            ),
          ),
        ],
      ),
      body: DefaultTextStyle(
        style: TextStyle(fontFamily: 'Inter', color: colors.onSurface, decoration: TextDecoration.none),
        child: Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: _saving,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListenableBuilder(
                        listenable: Listenable.merge([_draft.name, _draft.username, _draft.bio, _draft.city, _draft.country]),
                        builder: (ctx, _) => ProfileSocialCover(
                          displayName: _draft.name.text,
                          username: _draft.username.text,
                          bio: _draft.bio.text,
                          photoPath: _draft.photoPath,
                          coverPath: _draft.coverPath,
                          city: _draft.city.text,
                          country: _draft.country.text,
                          language: _draft.language,
                          gender: _draft.gender,
                          planTier: profile.planTier,
                          age: _draft.birthDate != null ? _draft.applyTo(profile).calculatedAge : profile.calculatedAge,
                          onEditAvatar: () => _pickMedia(isAvatar: true),
                          onEditCover: () => _pickMedia(isAvatar: false),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ProfileFormSections(
                        draft: _draft,
                        saving: _saving,
                        onSave: _save,
                        onFeedback: _notify,
                        onBirthDateChanged: (d) => mounted ? setState(() => _draft.birthDate = d) : null,
                        onGenderChanged: (g) => mounted ? setState(() => _draft.gender = g) : null,
                        onLanguageChanged: (l) => mounted ? setState(() => _draft.language = l) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
