import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// QUÉ HACE:
/// Tarjeta KPI compacta para visualizar métricas en vivo en el perfil Nano.
///
/// CÓMO FUNCIONA:
/// Diseñada con superficie óptica translúcida, icono con halo sutil, valor
/// numérico prominente y etiqueta semántica.
///
/// POR QUÉ:
/// Eleva la presentación de la cuenta a un estándar ejecutivo de monitoreo de
/// recursos de hardware, base de datos local y nodos conectados.
class ProfileMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? statusText;
  final Color? accentColor;
  final VoidCallback? onTap;

  const ProfileMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.statusText,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final effectiveAccent = accentColor ?? colors.primary;

    return Expanded(
      child: NanoOpticalSurface(
        borderRadius: NanoRadius.medium,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NanoRadius.small),
                  ),
                  child: Icon(icon, size: 14, color: effectiveAccent),
                ),
                const SizedBox(width: 4),
                if (statusText != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        statusText!,
                        style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: NanoType.title(colors.onSurface).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
