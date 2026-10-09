// messaging_app_tile.dart
//
// QUÉ HACE:
// Tarjeta individual de canal/app con diseño iOS Liquid Glass, borde metálico especular
// y reflejo iridiscente para la barra horizontal de apps del Centro de Mensajería.
//
// CÓMO FUNCIONA:
// - Construye un contenedor con doble degradado (borde metálico + fondo de cristal esmerilado).
// - Provee micro-animación al seleccionar e indicador numérico de no leídos con badge esmeralda.
//
// POR QUÉ:
// Desacopla la lógica visual de las tarjetas de la barra principal (SRP / SOLID) bajo 150 líneas.

import 'package:flutter/material.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_platform_icon.dart';

class MessagingAppTile extends StatelessWidget {
  final MessagingPlatform? platform;
  final String label;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;

  const MessagingAppTile({
    super.key,
    this.platform,
    required this.label,
    required this.isSelected,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderGradient = isSelected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.72),
                    const Color(0xFF38BDF8).withValues(alpha: 0.60),
                    const Color(0xFF818CF8).withValues(alpha: 0.45),
                    const Color(0xFFFFFFFF).withValues(alpha: 0.20),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFF38BDF8).withValues(alpha: 0.66),
                    const Color(0xFF94A3B8).withValues(alpha: 0.68),
                  ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.70),
                    Colors.white.withValues(alpha: 0.34),
                    const Color(0xFFCBD5E1).withValues(alpha: 0.42),
                  ],
          );

    final bgGradient = isSelected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF334155).withValues(alpha: 0.80),
                    const Color(0xFF1E293B).withValues(alpha: 0.90),
                    const Color(0xFF0F172A).withValues(alpha: 0.95),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.68),
                    const Color(0xFFF1F5F9).withValues(alpha: 0.46),
                  ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B).withValues(alpha: 0.55),
                    const Color(0xFF0F172A).withValues(alpha: 0.65),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.43),
                    const Color(0xFFF8FAFC).withValues(alpha: 0.25),
                  ],
          );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: borderGradient,
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                color: const Color(
                  0xFF38BDF8,
                ).withValues(alpha: isDark ? 0.25 : 0.18),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                blurRadius: 5,
                offset: const Offset(0, 1.5),
              ),
            ],
          ],
        ),
        padding: EdgeInsets.all(isSelected ? 1.3 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: bgGradient,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (platform != null)
                      MessagingPlatformIcon(
                        platform: platform!,
                        size: 21,
                        borderRadius: 6,
                      )
                    else
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? (isDark
                                    ? [
                                        const Color(0xFF38BDF8),
                                        const Color(0xFF818CF8),
                                      ]
                                    : [
                                        const Color(0xFF0284C7),
                                        const Color(0xFF4F46E5),
                                      ])
                              : (isDark
                                    ? [Colors.white70, Colors.white60]
                                    : [
                                        const Color(0xFF64748B),
                                        const Color(0xFF475569),
                                      ]),
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B)),
                        fontSize: 9.5,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3.5,
                      vertical: 1.5,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.45),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
