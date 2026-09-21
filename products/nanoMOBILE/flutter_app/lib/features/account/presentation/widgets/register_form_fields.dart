import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'nano_glass_field.dart';
import 'register_country_picker.dart';

class RegisterFormInputs extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final CountryInfo selectedCountry;
  final VoidCallback onSelectCountry;
  final bool acceptTerms;
  final ValueChanged<bool?> onAcceptTermsChanged;
  final NanoColors colors;

  const RegisterFormInputs({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.selectedCountry,
    required this.onSelectCountry,
    required this.acceptTerms,
    required this.onAcceptTermsChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: NanoGlassField(
                controller: firstNameController,
                label: 'Nombre',
                hint: 'Emmanuel',
                prefixIcon: Icons.person_outline_rounded,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: NanoSpacing.sm),
            Expanded(
              child: NanoGlassField(
                controller: lastNameController,
                label: 'Apellido',
                hint: 'Higuita',
                prefixIcon: Icons.badge_outlined,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: NanoSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('País de residencia', style: NanoType.caption(colors.onSurfaceVariant)),
            const SizedBox(height: 6),
            InkWell(
              onTap: onSelectCountry,
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              child: NanoOpticalSurface(
                borderRadius: NanoRadius.medium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Text(selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(selectedCountry.name, style: NanoType.body(colors.onSurface)),
                    ),
                    Text(
                      selectedCountry.dialCode,
                      style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down_rounded, color: colors.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NanoSpacing.md),
        NanoGlassField(
          controller: phoneController,
          label: 'Número de teléfono',
          hint: '300 123 4567',
          prefixIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Ingresa tu número de teléfono';
            if (val.trim().length < 7) return 'Número telefónico incompleto';
            return null;
          },
        ),
        const SizedBox(height: NanoSpacing.md),
        NanoGlassField(
          controller: emailController,
          label: 'Correo electrónico',
          hint: 'usuario@dominio.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Ingresa tu correo electrónico';
            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
            if (!emailRegex.hasMatch(val.trim())) return 'Formato de correo no válido';
            return null;
          },
        ),
        const SizedBox(height: NanoSpacing.md),
        NanoGlassField(
          controller: passwordController,
          label: 'Contraseña (mínimo 8 caracteres)',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          validator: (val) {
            if (val == null || val.length < 8) {
              return 'La contraseña debe tener al menos 8 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: NanoSpacing.md),
        NanoGlassField(
          controller: confirmController,
          label: 'Confirmar contraseña',
          hint: '••••••••',
          prefixIcon: Icons.lock_reset_rounded,
          isPassword: true,
          validator: (val) =>
              val != passwordController.text ? 'Las contraseñas no coinciden' : null,
        ),
        const SizedBox(height: NanoSpacing.md),
        Row(
          children: [
            Checkbox(
              value: acceptTerms,
              activeColor: colors.primary,
              checkColor: Colors.white,
              onChanged: onAcceptTermsChanged,
            ),
            Expanded(
              child: Text(
                'Acepto los Términos de Servicio y la Política de Privacidad de NanoAI.',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
