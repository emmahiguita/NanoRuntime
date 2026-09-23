// model_screen_helpers.dart — Auxiliares visuales y exportador de tipos para modelos.
// QUÉ HACE: Provee el banner de permisos de almacenamiento SD y el estado vacío animado.
// CÓMO FUNCIONA: Widgets desacoplados con NanoThemeExtension y micro-interacciones iOS/Material 3.
// POR QUÉ: Permite mantener componentes enfocados, reutilizables y bajo 200 líneas de código.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_action_components.dart';
export 'model_catalog_types.dart';

/// Banner visual para solicitar acceso a todos los archivos / tarjeta SD
class IosPermissionBanner extends StatelessWidget {
  final VoidCallback onRequestAccess;

  const IosPermissionBanner({super.key, required this.onRequestAccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(NanoRadius.medium),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sd_storage_rounded,
            size: 22,
            color: Color(0xFF6366F1),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acceso a Tarjeta SD / Almacenamiento',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Detecta y ejecuta modelos .gguf sin copiarlos a la memoria interna.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IosActionButton(
            label: 'Permitir',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF6366F1),
            filled: true,
            onTap: onRequestAccess,
          ),
        ],
      ),
    );
  }
}

/// Estado vacío profesional cuando no hay modelos coincidentes
class IosEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const IosEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: colors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 12),
              IosActionButton(
                label: actionLabel!,
                icon: Icons.refresh_rounded,
                onTap: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
