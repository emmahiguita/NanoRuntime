import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'nano_3d_crystal_icon.dart';

/// Presenta el modelo observado y su estado sin inventar nombre ni rendimiento.
/// El nombre y los indicadores fluyen en dos líneas para tolerar pantallas estrechas.
class NanoActiveModelGlassCard extends StatelessWidget {
  const NanoActiveModelGlassCard({
    super.key,
    required this.modelName,
    required this.isOnline,
    this.isGenerating = false,
    this.tps,
    this.onTap,
  });
  final String modelName;
  final bool isOnline;
  final bool isGenerating;
  final double? tps;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = modelName.trim();
    final measured = tps != null && tps!.isFinite && tps! > 0;
    final status = name.isEmpty
        ? 'Seleccionar modelo'
        : isGenerating
        ? 'Generando'
        : isOnline
        ? 'Disponible'
        : 'Sin conexión';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 1, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (onTap != null) {
                  onTap!();
                } else {
                  context.go('/models');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: dark ? 0.78 : 0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.72),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.background.withValues(
                        alpha: dark ? 0.18 : 0.06,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Nano3dCrystalIcon(size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name.isEmpty ? 'Sin modelo seleccionado' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            children: [
                              _ModelStatusBadge(
                                text: status,
                                color: colors.onSurfaceVariant,
                              ),
                              // La medición pertenece a la última respuesta, no prueba la velocidad actual.
                              Tooltip(
                                message:
                                    'Velocidad registrada en la última respuesta disponible.',
                                child: _ModelStatusBadge(
                                  text: measured
                                      ? '${tps!.toStringAsFixed(1)} t/s'
                                      : 'Sin medición',
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador discreto y compartido: un dato ausente no se colorea como éxito.
class _ModelStatusBadge extends StatelessWidget {
  const _ModelStatusBadge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.20), width: 0.7),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
