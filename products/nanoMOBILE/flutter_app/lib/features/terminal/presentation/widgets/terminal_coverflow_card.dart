import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import '../../domain/terminal_hub_card.dart';
import 'interactive_3d_turntable_box.dart';
import 'perspective_hero_flight.dart';

/// Miniatura física estilo GameCube Case para el carrusel Cover Flow.
class TerminalCover extends StatelessWidget {
  const TerminalCover({
    super.key,
    required this.card,
  });

  final TerminalHubCard card;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D18) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF25334D) : colors.borderSecondaryColor,
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: card.accent.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            // Fondo con degradado armónico jerárquico
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF162032),
                            Color(0xFF080C14),
                          ]
                        : [
                            colors.surface,
                            colors.backgroundIce,
                          ],
                  ),
                ),
              ),
            ),

            // Halo central con el color de acento del módulo
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: card.accent.withValues(alpha: isDark ? 0.22 : 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: card.accent.withValues(alpha: isDark ? 0.38 : 0.20),
                      blurRadius: 26,
                    ),
                  ],
                ),
              ),
            ),

            // Contenido gráfico de la portada
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner superior estilo GameCube: NANO RUNTIME
                  Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.85)
                          : colors.surfaceVariant.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : colors.borderSecondaryColor,
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 9,
                          color: card.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'NANO RUNTIME',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.90)
                                : colors.textPrimary,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Icono central del módulo
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: card.accent.withValues(alpha: 0.20),
                        border: Border.all(
                          color: card.accent.withValues(alpha: 0.70),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: card.accent.withValues(alpha: 0.35),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Icon(
                        card.icon,
                        color: card.accent,
                        size: 28,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Subtítulo y título de la portada
                  Text(
                    card.eyebrow,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: card.accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    card.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      shadows: isDark
                          ? const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Brillo especular shrinkwrap cellophane
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1.2, -1.0),
                      end: const Alignment(1.2, 1.0),
                      stops: const [0.0, 0.30, 0.40, 0.50, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
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
}

/// Tarjeta del carrusel 3D Cover Flow.
class TerminalHubSmallCard extends StatelessWidget {
  const TerminalHubSmallCard({
    super.key,
    required this.card,
    this.compact = false,
  });

  final TerminalHubCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return AspectRatio(
      aspectRatio: 0.66,
      child: Column(
        children: [
          Expanded(
            flex: 7,
            child: TerminalCover(card: card),
          ),
          const SizedBox(height: 8),
          Text(
            card.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: compact ? 13.5 : 15.5,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: card.accent.withValues(alpha: 0.90),
              fontFamily: 'Inter',
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Pantalla Modal transparente para la inspección 3D (360° Turntable + Información).
///
/// Reproduce con exactitud la composición del ejemplo:
/// - Fondo oscuro cinematográfico con desenfoque (`ImageFilter.blur`).
/// - Botón `...` en la esquina superior izquierda.
/// - Botón `X` en la esquina superior derecha para cerrar.
/// - Caja física 3D en el centro con perspectiva, grosor y rotación 360° interactiva.
/// - Panel inferior con título grande, badge de metadata, tags y descripción.
class TerminalHubDetailScreen extends StatelessWidget {
  const TerminalHubDetailScreen({
    super.key,
    required this.card,
  });

  final TerminalHubCard card;

  static void show(BuildContext context, TerminalHubCard card) {
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) {
          return capturedThemes.wrap(
            TerminalHubDetailScreen(card: card),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double width = math.min(screen.width, 500);
    // Identidad universal obsidian/dark
    const bool isDark = true;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Fondo cinematográfico adaptativo con desenfoque de cristal óptico
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),

          // Contenido principal de la ficha
          SafeArea(
            child: Center(
              child: SizedBox(
                width: width,
                height: screen.height,
                child: Hero(
                  tag: 'terminal-card-${card.id}',
                  createRectTween: (begin, end) {
                    return MaterialRectCenterArcTween(
                      begin: begin,
                      end: end,
                    );
                  },
                  flightShuttleBuilder: perspectiveHeroFlight,
                  child: Material(
                    color: Colors.transparent,
                    child: TerminalHubDetailCard(card: card),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ficha completa con Visor 3D y sección de información.
class TerminalHubDetailCard extends StatelessWidget {
  const TerminalHubDetailCard({
    super.key,
    required this.card,
  });

  final TerminalHubCard card;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.height < 600;
    final colors = NanoThemeExtension.of(context).colors;
    // Identidad universal obsidian/dark
    const bool isDark = true;

    return Stack(
      children: [
        // Contenido con scroll vertical
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            22,
            isCompact ? 16 : 48,
            22,
            isCompact ? 20 : 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // 1. VISOR 3D TURNTABLE INTERACTIVO (GAME CUBE PHYSICAL CASE)
              // -------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 20),
                child: Center(
                  child: Interactive3DTurntableBox(
                    card: card,
                    width: isCompact ? 165 : 200,
                    height: isCompact ? 225 : 275,
                    depth: 26,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // -------------------------------------------------------------
              // 2. TÍTULO PRINCIPAL (JERÁRQUICO CON TIPOGRAFÍA DEL SISTEMA)
              // -------------------------------------------------------------
              Text(
                card.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 6),

              // -------------------------------------------------------------
              // 3. SUB-FILA: ICONO DEL MÓDULO + METADATOS
              // -------------------------------------------------------------
              Row(
                children: [
                  Icon(
                    card.icon,
                    size: 15,
                    color: card.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${card.eyebrow} • 2026',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // -------------------------------------------------------------
              // 4. ETIQUETA / PILL TAGS ESTILO FICHA
              // -------------------------------------------------------------
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : colors.borderSecondaryColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 14,
                        color: card.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Standard Nano AI Case',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: colors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: card.accent.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ARM64',
                          style: TextStyle(
                            color: NanoTextColors.forText(card.accent, colors),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'READY',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // 5. PÁRRAFO DE DESCRIPCIÓN COMPLETA
              // -------------------------------------------------------------
              Text(
                card.description,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 18),

              // -------------------------------------------------------------
              // 6. CAPACIDADES INTEGRADAS
              // -------------------------------------------------------------
              Text(
                'CAPACIDADES INTEGRADAS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: NanoTextColors.forText(card.accent, colors),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              for (final highlight in card.highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: card.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          highlight,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 7. BOTÓN DE ACCIÓN / EJECUCIÓN DIRECTA
              // -------------------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(card.route);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    card.actionLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: colors.onAccent,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: card.accent,
                    foregroundColor: colors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: isDark ? 4 : 2,
                    shadowColor: card.accent.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),

        // -------------------------------------------------------------------
        // BOTÓN SUPERIOR IZQUIERDO: '...' (MÁS OPCIONES)
        // -------------------------------------------------------------------
        Positioned(
          top: 10,
          left: 10,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : colors.surface.withValues(alpha: 0.90),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : colors.borderSecondaryColor,
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: isDark ? Colors.white : colors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),

        // -------------------------------------------------------------------
        // BOTÓN SUPERIOR DERECHO: 'X' (CERRAR)
        // -------------------------------------------------------------------
        Positioned(
          top: 10,
          right: 10,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : colors.surface.withValues(alpha: 0.90),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : colors.borderSecondaryColor,
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : colors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
