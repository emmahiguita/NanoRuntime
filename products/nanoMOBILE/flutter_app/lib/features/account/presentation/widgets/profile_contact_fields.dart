// profile_contact_fields.dart — Bloque de contacto y preferencias de idioma.
// QUÉ HACE: Gestiona número de teléfono móvil, correo electrónico e idioma preferido.
// CÓMO FUNCIONA: Campos NanoGlassField con selector modal de idioma y teclado telefónico.
// POR QUÉ: Permite comunicación y configuración regional de la cuenta del usuario.
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';
import 'nano_glass_field.dart';

class ProfileContactFields extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const ProfileContactFields({
    super.key,
    required this.phoneController,
    required this.emailController,
    required this.language,
    required this.onLanguageChanged,
  });

  void _showLanguageSheet(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final languages = ['Español', 'English', 'Português', 'Français', 'Deutsch', 'Italiano'];
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NanoRadius.large)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text('Idioma preferido', style: NanoType.title(colors.onSurface)),
            const SizedBox(height: 8),
            ...languages.map((lang) => ListTile(
              title: Text(lang, style: NanoType.body(colors.onSurface)),
              trailing: language == lang ? const Icon(Icons.check_rounded, color: Color(0xFF10B981)) : null,
              onTap: () {
                Navigator.pop(ctx);
                onLanguageChanged(lang);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.contact_mail_outlined, size: 20, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('Contacto & Idioma', style: NanoType.title(colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        NanoGlassField(
          controller: phoneController,
          label: 'Teléfono móvil',
          hint: '+57 300 123 4567',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        NanoGlassField(
          controller: emailController,
          label: 'Correo electrónico',
          hint: 'emmanuel@correo.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        // Idioma preferido
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Idioma preferido',
                style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              onTap: () => _showLanguageSheet(context),
              child: NanoOpticalSurface(
                borderRadius: NanoRadius.medium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.translate_rounded, size: 19, color: colors.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        language.isNotEmpty ? language : 'Español',
                        style: NanoType.body(colors.onSurface),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: colors.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
