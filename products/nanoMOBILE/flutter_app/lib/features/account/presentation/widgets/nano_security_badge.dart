import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';

/// QUÉ HACE:
/// Badge de seguridad y soberanía tecnológica para Nano AI.
///
/// CÓMO FUNCIONA:
/// Muestra un indicador visual de alta fidelidad con micro-icono y texto
/// que certifica el estado de privacidad (Cifrado AES-256, Zero-Cloud, Sandbox).
///
/// POR QUÉ:
/// Comunica instantáneamente la propuesta de valor de soberanía de datos y seguridad
/// de grado industrial requerida en la pantalla de autenticación y centro de cuenta.
class NanoSecurityBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isShieldActive;

  const NanoSecurityBadge({
    super.key,
    this.label = 'Cifrado local AES-256 · Soberanía 100% en dispositivo',
    this.icon = Icons.verified_user_outlined,
    this.isShieldActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final activeColor = isShieldActive ? colors.primary : colors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: activeColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
