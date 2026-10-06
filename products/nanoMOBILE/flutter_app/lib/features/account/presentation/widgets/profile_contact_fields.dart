import 'package:flutter/material.dart';
import 'nano_glass_field.dart';
import 'profile_choice_field.dart';

/// Contacto e idioma del perfil; no modifica credenciales de acceso.
class ProfileContactFields extends StatelessWidget {
  final TextEditingController phoneController, emailController;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  const ProfileContactFields({
    super.key,
    required this.phoneController,
    required this.emailController,
    required this.language,
    required this.onLanguageChanged,
  });

  /// Avisa de errores básicos sin inventar correo ni teléfono.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Contacto e idioma', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: phoneController,
        label: 'Teléfono',
        hint: 'Número con indicativo de país',
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: emailController,
        label: 'Correo de contacto',
        hint: 'nombre@dominio.com',
        prefixIcon: Icons.mail_outline_rounded,
        helperText: 'No cambia el correo de acceso a tu cuenta.',
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          final email = (value ?? '').trim();
          return email.isEmpty ||
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
              ? null
              : 'Revisa el formato del correo.';
        },
      ),
      const SizedBox(height: 8),
      ProfileChoiceField(
        label: 'Idioma preferido',
        value: language,
        icon: Icons.translate_rounded,
        options: const [
          'Español',
          'English',
          'Português',
          'Français',
          'Deutsch',
          'Italiano',
        ],
        onChanged: onLanguageChanged,
      ),
    ],
  );
}
