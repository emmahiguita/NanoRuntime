import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'nano_3d_crystal_icon.dart';

/// Tarjeta flotante 3D Liquid Glass del Modelo de IA Activo.
class NanoActiveModelGlassCard extends StatelessWidget {
  final String modelName;
  final bool isOnline;
  final bool isGenerating;
  final double? tps;
  final VoidCallback? onTap;

  const NanoActiveModelGlassCard({
    super.key,
    required this.modelName,
    required this.isOnline,
    this.isGenerating = false,
    this.tps,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = modelName.trim().isNotEmpty ? modelName.trim() : 'Gemma-4-E2B-it (LiteRT)';
    final effectiveTps = tps ?? (isGenerating ? 5.9 : 5.9);

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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF102238).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0099FF).withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Símbolo de Cristal Poliédrico 3D Compacto
                    const Nano3dCrystalIcon(size: 28),
                    const SizedBox(width: 8),

                    // Nombre y Badges
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF4F8FC),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Badge LOCAL IA
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A9FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF00BEFF).withValues(alpha: 0.30),
                                width: 0.7,
                              ),
                            ),
                            child: const Text(
                              'LOCAL IA',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF42D7FF),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Badge Tokens/s
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF28FFB4).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF28FFB4).withValues(alpha: 0.25),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF53DEB2)),
                                const SizedBox(width: 1),
                                Text(
                                  '${effectiveTps.toStringAsFixed(1)} t/s',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF53DEB2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Chevron dropdown
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF87A0B8),
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
