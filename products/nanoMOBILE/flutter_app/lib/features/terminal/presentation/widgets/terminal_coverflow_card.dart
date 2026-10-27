import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import 'package:nanoai/features/home/buho_wallpaper.dart';
import '../../domain/terminal_hub_card.dart';
import 'interactive_3d_turntable_box.dart';
import 'perspective_hero_flight.dart';

part 'terminal_coverflow_small.dart';
part 'terminal_coverflow_detail_screen.dart';
part 'terminal_coverflow_detail_landscape.dart';
part 'terminal_coverflow_detail_landscape_info.dart';
part 'terminal_coverflow_detail_portrait.dart';
part 'terminal_coverflow_detail_heading.dart';
part 'terminal_coverflow_detail_tags.dart';
part 'terminal_coverflow_detail_content.dart';

/// Miniatura física de portada para el carrusel Cover Flow (Full-Bleed Campaign Artwork).
class TerminalCover extends StatelessWidget {
  const TerminalCover({super.key, required this.card});

  final TerminalHubCard card;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D18) : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF25334D) : colors.borderSecondaryColor,
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: card.accent.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arte de campaña en alta definición
            if (card.imageAsset != null)
              Image.asset(
                card.imageAsset!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackCover(colors, isDark),
              )
            else
              _buildFallbackCover(colors, isDark),

            // Brillo especular sutil en la superficie
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1.0, -1.0),
                      end: const Alignment(1.0, 1.0),
                      stops: const [0.0, 0.25, 0.45, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(NanoColors colors, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF162032), Color(0xFF080C14)]
              : [colors.surface, colors.backgroundIce],
        ),
      ),
      child: Center(child: Icon(card.icon, size: 48, color: card.accent)),
    );
  }
}

/// Tarjeta del carrusel 3D Cover Flow.
/// Selecciona una composición adaptativa sin duplicar acciones ni simular opciones.
class TerminalHubDetailCard extends StatelessWidget {
  const TerminalHubDetailCard({super.key, required this.card});
  final TerminalHubCard card;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.height < 550
        ? _landscape(context)
        : _portrait(context, size.height < 600);
  }
}

/// Mantiene la caja interactiva; detiene movimiento ambiental e inercia si se solicita.
class _MotionAwareTerminalBox extends StatelessWidget {
  const _MotionAwareTerminalBox({
    required this.card,
    required this.width,
    required this.height,
    required this.depth,
  });
  final TerminalHubCard card;
  final double width, height, depth;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TickerMode(
      enabled: !reduce,
      child: Interactive3DTurntableBox(
        card: card,
        width: width,
        height: height,
        depth: depth,
        autoRotate: !reduce,
      ),
    );
  }
}
