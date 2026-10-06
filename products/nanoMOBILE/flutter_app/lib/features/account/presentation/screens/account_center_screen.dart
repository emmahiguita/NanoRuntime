import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/account_providers.dart';
import '../controllers/profile_editor_draft.dart';
import '../controllers/profile_media_picker.dart';
import '../widgets/profile_form_sections.dart';
import '../widgets/profile_social_cover.dart';

/// Pantalla de perfil profesional con persistencia real y reactiva.
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
    setState(() => _saving = true);
    try {
      final profile = ref.read(sessionGateProvider).profile;
      await ref.read(sessionGateProvider.notifier).updateProfile(_draft.applyTo(profile));
      if (mounted) _notify('Perfil guardado exitosamente.');
    } catch (e) {
      if (mounted) _notify('No se pudo guardar el perfil: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await ProfileMediaPicker.pickImage(
      context: context,
      title: 'avatar',
      hasExisting: (_draft.photoPath ?? '').isNotEmpty,
    );
    if (!mounted || result == null) return;
    setState(() => _draft.photoPath = result.isEmpty ? null : result);
    final profile = ref.read(sessionGateProvider).profile;
    await ref.read(sessionGateProvider.notifier).updateProfile(_draft.applyTo(profile));
    if (mounted) _notify(result.isEmpty ? 'Foto de perfil eliminada.' : 'Foto de perfil actualizada.');
  }

  Future<void> _pickCover() async {
    final result = await ProfileMediaPicker.pickImage(
      context: context,
      title: 'portada',
      hasExisting: (_draft.coverPath ?? '').isNotEmpty,
    );
    if (!mounted || result == null) return;
    setState(() => _draft.coverPath = result.isEmpty ? null : result);
    final profile = ref.read(sessionGateProvider).profile;
    await ref.read(sessionGateProvider.notifier).updateProfile(_draft.applyTo(profile));
    if (mounted) _notify(result.isEmpty ? 'Foto de portada eliminada.' : 'Foto de portada actualizada.');
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
        leading: IconButton(
          tooltip: 'Volver',
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.40),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(_saving ? 'Guardando…' : 'Guardar', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: Form(
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
                      listenable: Listenable.merge([
                        _draft.name, _draft.username, _draft.bio, _draft.city, _draft.country,
                      ]),
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
                        age: _draft.birthDate != null
                            ? _draft.applyTo(profile).calculatedAge
                            : profile.calculatedAge,
                        onEditAvatar: _pickAvatar,
                        onEditCover: _pickCover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: colors.outline.withValues(alpha: 0.20), height: 1, indent: 20, endIndent: 20),
                    ProfileFormSections(
                      draft: _draft,
                      saving: _saving,
                      onSave: _save,
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
    );
  }
}
