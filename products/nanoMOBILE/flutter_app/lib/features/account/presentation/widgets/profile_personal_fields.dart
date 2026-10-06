import 'package:flutter/material.dart';
import 'nano_glass_field.dart';
import 'profile_birth_date_field.dart';
import 'profile_choice_field.dart';

/// Identidad editable; el padre posee los datos y decide cuándo guardarlos.
class ProfilePersonalFields extends StatelessWidget {
  final TextEditingController nameController, usernameController, bioController;
  final DateTime? birthDate;
  final String gender;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final ValueChanged<String> onGenderChanged;
  const ProfilePersonalFields({
    super.key,
    required this.nameController,
    required this.usernameController,
    required this.bioController,
    required this.birthDate,
    required this.gender,
    required this.onBirthDateChanged,
    required this.onGenderChanged,
  });

  /// Form valida el nombre; los otros datos siguen siendo opcionales.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Información personal',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: nameController,
        label: 'Nombre completo',
        hint: 'Tu nombre',
        prefixIcon: Icons.badge_outlined,
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'Escribe tu nombre.' : null,
      ),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: usernameController,
        label: 'Nombre de usuario',
        hint: '@usuario',
        prefixIcon: Icons.alternate_email_rounded,
      ),
      const SizedBox(height: 8),
      ProfileBirthDateField(value: birthDate, onChanged: onBirthDateChanged),
      ProfileChoiceField(
        label: 'Género',
        value: gender,
        icon: Icons.person_outline_rounded,
        options: const [
          'Masculino',
          'Femenino',
          'No binario',
          'Prefiero no decir',
        ],
        onChanged: onGenderChanged,
      ),
      const SizedBox(height: 8),
      NanoGlassField(
        controller: bioController,
        label: 'Sobre mí',
        hint: 'Escribe una breve descripción.',
        prefixIcon: Icons.edit_note_rounded,
        keyboardType: TextInputType.multiline,
        minLines: 3,
        maxLines: 5,
        textInputAction: TextInputAction.newline,
      ),
    ],
  );
}
