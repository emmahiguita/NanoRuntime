import 'package:flutter/material.dart';
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
///
/// - QUÉ HACE: Renderiza la tarjeta de Google, KPIs métricos, acordeones de edición
///   y opciones de gobernanza de cuenta.
/// - CÓMO FUNCIONA: Desacopla la vista de la persistencia (el botón de guardado único
///   reside en la barra de navegación superior estilo iOS).
/// - POR QUÉ: Elimina redundancias visuales de guardado y mantiene componentes
///   compactos, sobrios y de alta densidad de información.
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: GoogleAccountDashboardCard(),
        ),
        AccountKpiSection(onFeedback: onFeedback),
        ProfileSectionLabel(
          label: 'Configuración de Identidad',
          colors: colors,
        ),
        ProfileEditAccordion(
          icon: Icons.person_outline_rounded,
          iconColor: colors.onSurfaceVariant,
          title: 'Información personal',
          subtitle: 'Nombre, usuario, bio y fecha de nacimiento',
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
          icon: Icons.alternate_email_rounded,
          iconColor: colors.onSurfaceVariant,
          title: 'Contacto e idioma',
          subtitle: 'Email, teléfono y lenguaje preferido de IA',
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
          iconColor: colors.onSurfaceVariant,
          title: 'Ubicación y zona',
          subtitle: 'País, región, ciudad y dirección local',
          colors: colors,
          child: ProfileLocationFields(
            countryController: draft.country,
            stateController: draft.region,
            cityController: draft.city,
            addressController: draft.address,
          ),
        ),
        const SizedBox(height: 10),
        Divider(
          color: colors.outlineVariant.withValues(alpha: 0.25),
          height: 1,
          indent: 20,
          endIndent: 20,
        ),
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
