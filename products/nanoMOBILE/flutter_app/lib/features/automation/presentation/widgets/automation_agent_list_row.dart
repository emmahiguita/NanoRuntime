// automation_agent_list_row.dart — Fila interactiva de agente sin card rígida.
// QUÉ HACE:
// Renderiza una fila táctil elástica (Nano Personal, Negocio o Modelos) con squircle iOS,
// tipografía Inter (14.5dp título, 12dp subtítulo) y chevron aprovechando todo el ancho.
//
// CÓMO FUNCIONA:
// Al presionar, aplica micro-escala amortiguada (0.985) con AnimatedScale y feedback háptico.
//
// POR QUÉ:
// Elimina contenedores de tarjeta innecesarios y optimiza el espacio horizontal (< 130 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../automation_visual_theme.dart';

class AutomationAgentListRow extends StatefulWidget {
  const AutomationAgentListRow({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  State<AutomationAgentListRow> createState() => _AutomationAgentListRowState();
}

class _AutomationAgentListRowState extends State<AutomationAgentListRow> {
  bool _pressed = false;

  void _handleHighlightChanged(bool isHighlighted) {
    if (_pressed != isHighlighted && mounted) {
      setState(() => _pressed = isHighlighted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onHighlightChanged: _handleHighlightChanged,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Row(
                children: [
                  widget.avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: visual.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                            color: visual.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 10),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: visual.textMuted.withValues(alpha: 0.60),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
