// model_card_action_button.dart — Botón de acción con Thinking Orb de Libraries.dev.
// QUÉ HACE: Renderiza la acción contextual (Descargar, Cargar, Activo, Cancelar) y Thinking Orb en carga.
// CÓMO FUNCIONA: Botón estilo píldora Material 3 y estado de carga semántico reactivo.
// POR QUÉ: Cumple con la estética de Libraries.dev y límite estricto < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/effects/nano_thinking_orb.dart';
import '../../../../core/widgets/effects/nano_thinking_orb_theme.dart';
import 'model_screen_helpers.dart';

class ModelCardActionButton extends StatelessWidget {
  final ModelUiStatus status;
  final bool isActive;
  final bool isLoading;
  final double sizeGb;
  final VoidCallback? onUse;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onUnload;

  const ModelCardActionButton({
    super.key,
    required this.status,
    required this.isActive,
    required this.isLoading,
    required this.sizeGb,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: NanoThinkingOrb(size: 22, state: NanoOrbState.thinking),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isActive) {
      return InkWell(
        onTap: onUnload,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 12,
                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              ),
              const SizedBox(width: 3),
              Text(
                'Activo',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (status == ModelUiStatus.installed) {
      return InkWell(
        onTap: onUse,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                : const Color(0xFF0284C7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                  : const Color(0xFF0284C7).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 13,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
              ),
              const SizedBox(width: 2),
              Text(
                'Cargar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (status == ModelUiStatus.downloading) {
      return InkWell(
        onTap: onCancel,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
              SizedBox(width: 2),
              Text(
                'Parar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onDownload,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
              : const Color(0xFF2563EB).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                : const Color(0xFF2563EB).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_rounded,
              size: 12.5,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
            ),
            const SizedBox(width: 3),
            Text(
              '${sizeGb.toStringAsFixed(1)} GB',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
