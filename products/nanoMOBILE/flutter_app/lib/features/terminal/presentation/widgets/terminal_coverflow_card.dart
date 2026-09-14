import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import 'package:nanoai/features/home/buho_wallpaper.dart';
import '../../domain/terminal_hub_card.dart';
import 'interactive_3d_turntable_box.dart';
import 'perspective_hero_flight.dart';

/// Miniatura física de portada para el carrusel Cover Flow (Full-Bleed Campaign Artwork).
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
      child: Center(
        child: Icon(
          card.icon,
          size: 48,
          color: card.accent,
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
    this.titleOpacity = 1.0,
  });

  final TerminalHubCard card;
  final bool compact;
  final double titleOpacity;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.66,
      child: Column(
        children: [
          Expanded(
            child: TerminalCover(card: card),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: titleOpacity.clamp(0.0, 1.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: compact ? 18 : 22,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 14 : 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: compact ? 14 : 16,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.eyebrow,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: card.accent,
                          fontFamily: 'Inter',
                          fontSize: compact ? 10 : 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final bool isLandscape = screen.width > screen.height && screen.height < 550;
    final double width = isLandscape
        ? math.min(screen.width * 0.92, 780.0)
        : math.min(screen.width, 500.0);
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Fondo cinematográfico con el wallpaper del Búho y desenfoque de cristal óptico
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const BuhoWallpaper(scrimOpacity: 0.35),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: ColoredBox(
                      color: isDark 
                          ? Colors.black.withValues(alpha: 0.55)
                          : colors.surface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
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
    final isLandscape = screen.width > screen.height && screen.height < 550;
    final isCompact = screen.height < 600;
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    if (isLandscape) {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Columna Izquierda: Visor 3D Turntable Box centrado
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Interactive3DTurntableBox(
                      card: card,
                      width: 145,
                      height: 205,
                      depth: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                // Columna Derecha: Información y botón de ejecución
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              card.icon,
                              size: 13,
                              color: card.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${card.eyebrow} • 2026',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.description,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final highlight in card.highlights)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: card.accent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    highlight,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: colors.textPrimary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: () {
                              final router = GoRouter.of(context);
                              Navigator.of(context, rootNavigator: true).pop();
                              router.push(card.route);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: Text(
                              card.actionLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.onAccent,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: card.accent,
                              foregroundColor: colors.onAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: isDark ? 4 : 2,
                              shadowColor: card.accent.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 36,
                  height: 36,
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
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

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
                    width: isCompact ? 175 : 210,
                    height: isCompact ? 250 : 300,
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.textPrimary,
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
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textSecondary,
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
                    final router = GoRouter.of(context);
                    Navigator.of(context, rootNavigator: true).pop();
                    router.push(card.route);
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
