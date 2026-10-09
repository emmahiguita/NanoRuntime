import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_tokens.dart';
import '../controllers/profile_editor_draft.dart';
import 'account_kpi_section.dart';
import 'google_account_dashboard_card.dart';
import 'profile_accordion.dart';
import 'profile_account_actions.dart';
import 'profile_contact_fields.dart';
import 'profile_location_fields.dart';
import 'profile_personal_fields.dart';

/// Secciones de edición del perfil con acabado iOS Glass, miniaturas y acordeones.
class ProfileFormSections extends StatelessWidget {
  final ProfileEditorDraft draft;
  final bool saving;
  final VoidCallback onSave;
  final void Function(DateTime?) onBirthDateChanged;
  final void Function(String) onGenderChanged;
  final void Function(String) onLanguageChanged;
  final void Function(String message)? onFeedback;

  const ProfileFormSections({
    super.key,
    required this.draft,
    required this.saving,
    required this.onSave,
    required this.onBirthDateChanged,
    required this.onGenderChanged,
    required this.onLanguageChanged,
    this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: GoogleAccountDashboardCard()),
        AccountKpiSection(colors: colors, onFeedback: onFeedback),
        ProfileSectionLabel(label: 'Configuración de Identidad', colors: colors),
        ProfileEditAccordion(
          icon: Icons.person_rounded, iconColor: colors.primary,
          title: 'Información personal', subtitle: 'Nombre, usuario, bio y fecha de nacimiento', colors: colors,
          child: ProfilePersonalFields(
            nameController: draft.name, usernameController: draft.username, bioController: draft.bio,
            birthDate: draft.birthDate, gender: draft.gender, onBirthDateChanged: onBirthDateChanged, onGenderChanged: onGenderChanged,
          ),
        ),
        ProfileEditAccordion(
          icon: Icons.alternate_email_rounded, iconColor: const Color(0xFF6366F1),
          title: 'Contacto e idioma', subtitle: 'Email, teléfono y lenguaje preferido de IA', colors: colors,
          child: ProfileContactFields(phoneController: draft.phone, emailController: draft.email, language: draft.language, onLanguageChanged: onLanguageChanged),
        ),
        ProfileEditAccordion(
          icon: Icons.location_on_rounded, iconColor: const Color(0xFF10B981),
          title: 'Ubicación y zona', subtitle: 'País, región, ciudad y dirección local', colors: colors,
          child: ProfileLocationFields(countryController: draft.country, stateController: draft.region, cityController: draft.city, addressController: draft.address),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _GlassSaveButton(saving: saving, onSave: onSave, colors: colors),
        ),
        const SizedBox(height: 16),
        Divider(color: colors.outlineVariant.withValues(alpha: 0.35), height: 1, indent: 20, endIndent: 20),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ProfileAccountActions(disabled: saving),
        ),
        const SizedBox(height: 36),
      ],
    );
  }
}

class _GlassSaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final NanoColors colors;

  const _GlassSaveButton({required this.saving, required this.onSave, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: saving ? null : () { HapticFeedback.lightImpact(); onSave(); },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: 0.85)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (saving) ...[
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 10),
                    const Text('Guardando cambios…', style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ] else ...[
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Guardar cambios del perfil', style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
