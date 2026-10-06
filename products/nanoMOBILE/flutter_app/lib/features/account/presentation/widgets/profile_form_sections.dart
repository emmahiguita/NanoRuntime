import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../controllers/profile_editor_draft.dart';
import 'google_account_dashboard_card.dart';
import 'profile_accordion.dart';
import 'profile_account_actions.dart';
import 'profile_contact_fields.dart';
import 'profile_location_fields.dart';
import 'profile_personal_fields.dart';

/// Bloque de secciones de edición del perfil con acordeones y tarjeta de Google.
class ProfileFormSections extends StatelessWidget {
  final ProfileEditorDraft draft;
  final bool saving;
  final VoidCallback onSave;
  final void Function(DateTime?) onBirthDateChanged;
  final void Function(String) onGenderChanged;
  final void Function(String) onLanguageChanged;

  const ProfileFormSections({
    super.key,
    required this.draft,
    required this.saving,
    required this.onSave,
    required this.onBirthDateChanged,
    required this.onGenderChanged,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GoogleAccountDashboardCard(),
        ),
        ProfileSectionLabel(label: 'Editar perfil', colors: colors),
        ProfileEditAccordion(
          icon: Icons.person_outline_rounded,
          title: 'Información personal',
          colors: colors,
          child: ProfilePersonalFields(
            nameController: draft.name,
            usernameController: draft.username,
            bioController: draft.bio,
            birthDate: draft.birthDate,
            gender: draft.gender,
            onBirthDateChanged: onBirthDateChanged,
            onGenderChanged: onGenderChanged,
          ),
        ),
        ProfileEditAccordion(
          icon: Icons.mail_outline_rounded,
          title: 'Contacto e idioma',
          colors: colors,
          child: ProfileContactFields(
            phoneController: draft.phone,
            emailController: draft.email,
            language: draft.language,
            onLanguageChanged: onLanguageChanged,
          ),
        ),
        ProfileEditAccordion(
          icon: Icons.location_on_outlined,
          title: 'Ubicación',
          colors: colors,
          child: ProfileLocationFields(
            countryController: draft.country,
            stateController: draft.region,
            cityController: draft.city,
            addressController: draft.address,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              saving ? 'Guardando cambios…' : 'Guardar cambios del perfil',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: colors.outline.withValues(alpha: 0.15), height: 1, indent: 20, endIndent: 20),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ProfileAccountActions(disabled: saving),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
