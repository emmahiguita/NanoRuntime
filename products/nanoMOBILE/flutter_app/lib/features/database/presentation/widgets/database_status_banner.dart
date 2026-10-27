// database_status_banner.dart
//
// QUÉ HACE:
// Muestra mensajes de estado, errores de ejecución, métricas de latencia
// y el indicador de sincronización en tiempo real con Google Sheets.
//
// CÓMO FUNCIONA:
// - Si hay error, resalta en rojo Material Expressive con icono de alerta.
// - Si hay sincronización en vivo (isLiveSyncActive), renderiza una insignia verde
//   con icono animado de sincronización y botón para forzar actualización inmediata.
// - Muestra latencia medida en milisegundos de la última consulta SQL.
//
// POR QUÉ:
// Aplica SOLID (SRP) proporcionando retroalimentación visual clara sin acoplar
// la gestión de estado a la jerarquía de vistas superiores (< 130 líneas).

library;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

class DatabaseStatusBanner extends StatelessWidget {
  final String? errorMessage;
  final String? statusMessage;
  final int? latencyMs;
  final bool isLiveSyncActive;
  final VoidCallback? onSyncNow;
  final NanoColors colors;

  const DatabaseStatusBanner({
    super.key,
    this.errorMessage,
    this.statusMessage,
    this.latencyMs,
    this.isLiveSyncActive = false,
    this.onSyncNow,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: colors.error.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (statusMessage != null && statusMessage!.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        color: isLiveSyncActive
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : colors.surfaceVariant.withValues(alpha: 0.25),
        child: Row(
          children: [
            if (isLiveSyncActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 11,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'EN VIVO',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: colors.success,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                statusMessage!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isLiveSyncActive ? const Color(0xFF10B981) : colors.onSurface,
                  fontWeight: isLiveSyncActive ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLiveSyncActive && onSyncNow != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onSyncNow,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
            if (latencyMs != null) ...[
              const SizedBox(width: 6),
              Text(
                'ms',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
