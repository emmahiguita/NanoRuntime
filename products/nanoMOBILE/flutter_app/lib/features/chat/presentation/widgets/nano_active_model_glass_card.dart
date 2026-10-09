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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1B2B).withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6EBEFF).withValues(alpha: 0.18),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0099FF).withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Símbolo de Cristal Poliédrico 3D
                    const Nano3dCrystalIcon(size: 38),
                    const SizedBox(width: 12),

                    // Nombre y Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF4F8FC),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Badge LOCAL IA
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A9FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF00BEFF).withValues(alpha: 0.28),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'LOCAL IA',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF42D7FF),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Badge Tokens/s con rayo
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF28FFB4).withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF28FFB4).withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 11, color: Color(0xFF53DEB2)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${effectiveTps.toStringAsFixed(1)} t/s',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF53DEB2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Chevron dropdown
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
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
