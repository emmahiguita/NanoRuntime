// automation_row_item.dart — Fila de herramienta con micro-squircle y física táctil.
// QUÉ HACE:
// Renderiza una fila interactiva abierta en Herramientas con cápsula squircle para el icono,
// título semántico (14.5dp), subtítulo descriptivo (12dp) y chevron de navegación.
//
// CÓMO FUNCIONA:
// Al presionar la fila, ejecuta micro-compresión elástica (0.985) con curva easeOutCubic,
// emite haptic feedback (selectionClick) y aprovecha al máximo el ancho de la pantalla.
//
// POR QUÉ:
// Elimina la card exterior manteniendo el acabado Liquid Glass en los controles (< 160 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../automation_visual_theme.dart';

class AutomationRowItem extends StatefulWidget {
  const AutomationRowItem({
    super.key,
    this.icon,
    this.customIcon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.statusWidget,
    this.horizontalPadding = 4.0,
  }) : assert(icon != null || customIcon != null);

  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? statusWidget;
  final double horizontalPadding;

  @override
  State<AutomationRowItem> createState() => _AutomationRowItemState();
}

class _AutomationRowItemState extends State<AutomationRowItem> {
  bool _pressed = false;

  void _handleHighlightChanged(bool isHighlighted) {
    if (_pressed != isHighlighted && mounted) {
      setState(() => _pressed = isHighlighted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final dark = visual.isDark;

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
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
                vertical: 7,
              ),
              child: Row(
                children: [
                  // Micro-cápsula squircle de cristal para el icono
                  ExcludeSemantics(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.07),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: widget.customIcon ??
                            Icon(widget.icon, size: 20, color: visual.text),
                      ),
                    ),
                  ),
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
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
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
                      ],
                    ),
                  ),
                  if (widget.statusWidget != null) ...[
                    const SizedBox(width: 8),
                    widget.statusWidget!,
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
