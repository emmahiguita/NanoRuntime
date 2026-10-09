import 'dart:ui';
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
        content: Text(message),
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.38),
                  child: InkWell(
                    onTap: () => context.canPop() ? context.pop() : context.go('/settings'),
                    child: const SizedBox(width: 38, height: 38, child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saving)
                            const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          else
                            const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(_saving ? 'Guardando…' : 'Guardar', style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
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
                      listenable: Listenable.merge([_draft.name, _draft.username, _draft.bio, _draft.city, _draft.country]),
                      builder: (ctx, _) => ProfileSocialCover(
                        displayName: _draft.name.text, username: _draft.username.text, bio: _draft.bio.text,
                        photoPath: _draft.photoPath, coverPath: _draft.coverPath, city: _draft.city.text,
                        country: _draft.country.text, language: _draft.language, gender: _draft.gender,
                        planTier: profile.planTier, age: _draft.birthDate != null ? _draft.applyTo(profile).calculatedAge : profile.calculatedAge,
                        onEditAvatar: () => _pickMedia(isAvatar: true), onEditCover: () => _pickMedia(isAvatar: false),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProfileFormSections(
                      draft: _draft, saving: _saving, onSave: _save, onFeedback: _notify,
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
