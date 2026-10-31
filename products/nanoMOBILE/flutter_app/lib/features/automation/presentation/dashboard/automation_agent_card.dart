// automation_agent_card.dart — Tarjeta horizontal de agente con estética iOS Adaptive Glass.
// QUÉ HACE: Presenta la tarjeta de agente con icono, título, subtítulo, estado y flecha chevron.
// CÓMO FUNCIONA: Utiliza [GlassSurface], micro-interacción táctil y tipografía semántica.
// POR QUÉ: Replica con precisión la composición visual aprobada sin tarjetas cuadradas dispersas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/nano_motion_tokens.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../automation_visual_theme.dart';

class AutomationAgentCard extends StatefulWidget {
  const AutomationAgentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconWidget,
    required this.onTap,
    this.isActive = false,
    this.showStatus = false,
    this.statusLabel,
    this.channels = const [],
    this.metricLabel,
  });

  final String title;
  final String subtitle;
  final Widget iconWidget;
  final VoidCallback onTap;
  final bool isActive;
  final bool showStatus;
  final String? statusLabel;
  final List<String> channels;
  final String? metricLabel;

  @override
  State<AutomationAgentCard> createState() => _AutomationAgentCardState();
}

class _AutomationAgentCardState extends State<AutomationAgentCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = AutomationVisual.of(context);
    final reduceMotion = NanoMotionTokens.reduceMotion(context);

    final statusText = widget.statusLabel ?? (widget.isActive ? 'Activo' : 'Pausado');

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}. ${widget.showStatus ? statusText : ""}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: reduceMotion
              ? Duration.zero
              : NanoMotionTokens.touchResponse,
          curve: NanoMotionTokens.touchPress,
          child: GlassSurface(
            radius: 20,
            blur: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Icono temático del agente
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(child: widget.iconWidget),
                ),
                const SizedBox(width: 14),
                // 2. Título y subtítulo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: visual.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: visual.textMuted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 3. Badge de estado opcional (ej: "Pausado")
                if (widget.showStatus) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: visual.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: visual.cardBorder.withValues(alpha: 0.60),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: visual.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // 4. Chevron de navegación
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: visual.textMuted.withValues(alpha: 0.70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
