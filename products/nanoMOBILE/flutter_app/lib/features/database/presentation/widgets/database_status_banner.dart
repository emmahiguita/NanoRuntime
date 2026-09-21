import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Componente modular para mostrar estados de éxito o mensajes de error de consultas
class DatabaseStatusBanner extends StatelessWidget {
  final String? errorMessage;
  final String? statusMessage;
  final int? latencyMs;
  final NanoColors colors;

  const DatabaseStatusBanner({
    super.key,
    this.errorMessage,
    this.statusMessage,
    this.latencyMs,
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
        color: colors.surfaceVariant.withValues(alpha: 0.25),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 14,
              color: colors.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusMessage!,
                style: TextStyle(fontSize: 11.5, color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (latencyMs != null)
              Text(
                '${latencyMs}ms',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
