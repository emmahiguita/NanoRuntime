// profile_location_fields.dart — Bloque de ubicación y residencia del usuario.
// QUÉ HACE: Gestiona país, departamento/estado, ciudad y dirección residencial.
// CÓMO FUNCIONA: Campos NanoGlassField con iconos alusivos a geografía y hogar.
// POR QUÉ: Permite asociar residencia personal sin vincular datos de red o IPs.
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import 'nano_glass_field.dart';

class ProfileLocationFields extends StatelessWidget {
  final TextEditingController countryController;
  final TextEditingController stateController;
  final TextEditingController cityController;
  final TextEditingController addressController;

  const ProfileLocationFields({
    super.key,
    required this.countryController,
    required this.stateController,
    required this.cityController,
    required this.addressController,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('Ubicación', style: NanoType.title(colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: NanoGlassField(
                controller: countryController,
                label: 'País',
                hint: 'Colombia',
                prefixIcon: Icons.public_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NanoGlassField(
                controller: stateController,
                label: 'Departamento / Estado',
                hint: 'Antioquia',
                prefixIcon: Icons.map_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NanoGlassField(
          controller: cityController,
          label: 'Ciudad',
          hint: 'Medellín',
          prefixIcon: Icons.location_city_rounded,
        ),
        const SizedBox(height: 12),
        NanoGlassField(
          controller: addressController,
          label: 'Dirección residencial',
          hint: 'Ej: Carrera 43A # 1-50',
          prefixIcon: Icons.home_outlined,
        ),
      ],
    );
  }
}
