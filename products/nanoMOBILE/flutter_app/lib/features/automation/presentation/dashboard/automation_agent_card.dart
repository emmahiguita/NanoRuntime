// automation_agent_card.dart — Cuadro compacto M3 para Nano Personal y Nano Negocio.
// QUÉ HACE: Renderiza cada agente como un cuadro compacto y organizado, sin estiramientos.
// CÓMO FUNCIONA: Estructura vertical fija con icono, estado lumínico, métrica y respuesta háptica.
// POR QUÉ: Elimina el diseño alargado horizontal/vertical cumpliendo Material 3 Expressive (< 200 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../automation_visual_theme.dart';

class AutomationAgentCard extends StatefulWidget {
  final String title, subtitle;
  final bool isActive;
  final Widget iconWidget;
  final List<String> channels;
  final String? metricLabel;
  final VoidCallback onTap;

  const AutomationAgentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.iconWidget,
    required this.channels,
    this.metricLabel,
    required this.onTap,
  });

  @override
  State<AutomationAgentCard> createState() => _AutomationAgentCardState();
}

class _AutomationAgentCardState extends State<AutomationAgentCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final accent = widget.isActive ? visual.accent : visual.textMuted;

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}. Estado: ${widget.isActive ? "Activo" : "Pausado"}.',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [visual.surface.withValues(alpha: 0.92), const Color(0xFF091419)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.isActive ? visual.accent.withValues(alpha: 0.35) : visual.outline.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 6)),
                if (widget.isActive)
                  BoxShadow(color: visual.accent.withValues(alpha: 0.08), blurRadius: 18, spreadRadius: -2, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Icono + Badge estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.28)),
                      ),
                      child: Center(child: widget.iconWidget),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                              boxShadow: widget.isActive ? [BoxShadow(color: accent, blurRadius: 4)] : null,
                            ),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            widget.isActive ? 'Activo' : 'Pausa',
                            style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                // 2. Título principal
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: visual.text, fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                const SizedBox(height: 2),
                // 3. Subtítulo
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: visual.textMuted, fontSize: 11.0, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 9),
                // 4. Métrica inferior
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 11, color: widget.isActive ? visual.accent : visual.textMuted),
                      const SizedBox(width: 3.5),
                      Flexible(
                        child: Text(
                          widget.metricLabel ?? widget.channels.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: widget.isActive ? visual.text : visual.textMuted, fontSize: 10.0, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
