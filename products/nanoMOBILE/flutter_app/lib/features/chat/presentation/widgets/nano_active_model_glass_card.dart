import 'dart:ui';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Cápsula compacta estilo iOS Dynamic Island para el modelo activo.
///
/// Presenta el modelo seleccionado y su estado honesto con diseño ultra-limpio.
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

    final Color dotColor = isGenerating
        ? const Color(0xFF38BDF8)
        : (isOnline ? const Color(0xFF34C759) : const Color(0xFF94A3B8));

    final String statusText = name.isEmpty
        ? 'Elegir modelo'
        : isGenerating
        ? 'Generando'
        : isOnline
        ? 'Listo'
        : 'En reposo';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: dark ? 0.72 : 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                      width: 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.background.withValues(
                          alpha: dark ? 0.20 : 0.05,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: [
                            if (isOnline || isGenerating)
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.6),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          name.isEmpty ? 'Sin modelo' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• $statusText',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (measured) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${tps!.toStringAsFixed(1)} t/s)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.chevron_up_chevron_down,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
