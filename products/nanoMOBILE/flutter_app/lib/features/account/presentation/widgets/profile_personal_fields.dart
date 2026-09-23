// profile_personal_fields.dart — Bloque de información personal y biográfica.
// QUÉ HACE: Gestiona nombre completo, @usuario, selector de fecha de nacimiento con edad y género.
// CÓMO FUNCIONA: Campos NanoGlassField desacoplados con modal de género y date picker nativo.
// POR QUÉ: Otorga captura ergonómica y profesional de los datos clave de la persona humana.
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';
import 'nano_glass_field.dart';

class ProfilePersonalFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController bioController;
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

  String _formatDate(DateTime d) {
    const m = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  int? _calcAge(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    int age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age >= 0 ? age : null;
  }

  void _showGenderSheet(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
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
            Text('Seleccionar género', style: NanoType.title(colors.onSurface)),
            const SizedBox(height: 8),
            ...['Masculino', 'Femenino', 'No binario', 'Prefiero no decir'].map((opt) => ListTile(
              title: Text(opt, style: NanoType.body(colors.onSurface)),
              trailing: gender == opt ? const Icon(Icons.check_rounded, color: Color(0xFF10B981)) : null,
              onTap: () { Navigator.pop(ctx); onGenderChanged(opt); },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final age = _calcAge(birthDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('Información personal', style: NanoType.title(colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        NanoGlassField(
          controller: nameController,
          label: 'Nombre completo',
          hint: 'Emmanuel Higuita',
          prefixIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        NanoGlassField(
          controller: usernameController,
          label: 'Nombre de usuario',
          hint: '@emmanuel',
          prefixIcon: Icons.alternate_email_rounded,
        ),
        const SizedBox(height: 12),
        // Fecha de nacimiento
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha de nacimiento',
                style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: birthDate ?? DateTime(1996, 5, 24),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (picked != null) onBirthDateChanged(picked);
              },
              child: NanoOpticalSurface(
                borderRadius: NanoRadius.medium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, size: 19, color: colors.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        birthDate != null ? _formatDate(birthDate!) : 'Agregar fecha',
                        style: NanoType.body(birthDate != null ? colors.onSurface : colors.onSurfaceVariant.withValues(alpha: 0.55)),
                      ),
                    ),
                    if (age != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$age años', style: NanoType.caption(const Color(0xFF10B981)).copyWith(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Selector de género
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Género', style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              onTap: () => _showGenderSheet(context),
              child: NanoOpticalSurface(
                borderRadius: NanoRadius.medium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.transgender_rounded, size: 19, color: colors.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        gender.isNotEmpty ? gender : 'Opcional',
                        style: NanoType.body(gender.isNotEmpty ? colors.onSurface : colors.onSurfaceVariant.withValues(alpha: 0.55)),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: colors.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NanoGlassField(
          controller: bioController,
          label: 'Sobre mí (Biografía)',
          hint: 'Breve descripción personal...',
          prefixIcon: Icons.edit_note_rounded,
        ),
      ],
    );
  }
}
