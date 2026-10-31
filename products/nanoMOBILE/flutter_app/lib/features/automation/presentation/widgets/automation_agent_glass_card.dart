// automation_agent_glass_card.dart — Tarjeta individual Liquid Glass para Tus Agentes.
// QUÉ HACE: Renderiza una tarjeta compacta estilo iOS donde el icono oficial cubre toda la superficie.
// CÓMO FUNCIONA: Emplea coverImage con BoxFit.cover, degradado scrim inferior, borde óptico y escala táctil.
// POR QUÉ: Satisface la solicitud de que los iconos cubran toda la card con proporciones compactas.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../automation_visual_theme.dart';
import 'automation_agent_card_content.dart';

class AutomationAgentGlassCard extends StatefulWidget {
  const AutomationAgentGlassCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.coverImage,
    required this.onTap,
    required this.accentColor,
    required this.gradientColors,
    required this.borderColor,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final String? coverImage;
  final VoidCallback? onTap;
  final Color accentColor;
  final List<Color> gradientColors;
  final Color borderColor;

  @override
  State<AutomationAgentGlassCard> createState() =>
      _AutomationAgentGlassCardState();
}

class _AutomationAgentGlassCardState extends State<AutomationAgentGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final disableAnimations =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.of(context).accessibleNavigation;

    final scale = _pressed && !disableAnimations ? 0.975 : 1.0;
    const radius = BorderRadius.all(Radius.circular(16));

    return Semantics(
      button: true,
      label: '${widget.title}, ${widget.subtitle ?? ""}',
      enabled: widget.onTap != null,
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: scale,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: visual.isDark ? 0.40 : 0.12,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Imagen que cubre toda la tarjeta
                  if (widget.coverImage != null)
                    Image.asset(
                      widget.coverImage!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                    )
                  else
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.gradientColors,
                          ),
                        ),
                      ),
                    ),

                  // 2. Degradado inferior (scrim) para máxima legibilidad
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.35, 0.65, 1.0],
                      ),
                    ),
                  ),

                  // 3. Borde óptico especular
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: _pressed
                            ? widget.accentColor.withValues(alpha: 0.75)
                            : widget.borderColor,
                        width: 0.9,
                      ),
                    ),
                  ),

                  // 4. Chevron superior derecho
                  const AgentCardChevron(),

                  // 5. Textos e indicadores en la base de la tarjeta
                  AgentCardFooter(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    badge: widget.badge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
