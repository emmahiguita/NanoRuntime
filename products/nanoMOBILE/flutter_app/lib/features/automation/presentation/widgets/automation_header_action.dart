// automation_header_action.dart — Botón de acción superior con CupertinoIcons.
// QUÉ HACE: Renderiza los botones de cabecera (voz, mic, herramientas) con área táctil accesible y ancho compacto.
// CÓMO FUNCIONA: Usa CupertinoIcons, tamaño 22, respuesta elástica y soporte para semántica.
// POR QUÉ: Diseño iOS sobrio que evita truncamientos en el título de cabecera.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum AutomationHeaderActionType { voice, mic, devTools }

class AutomationHeaderAction extends StatelessWidget {
  const AutomationHeaderAction({
    super.key,
    required this.label,
    required this.actionType,
    required this.onTap,
    this.active,
    this.muted = false,
  });

  final String label;
  final AutomationHeaderActionType actionType;
  final VoidCallback? onTap;
  final bool? active;
  final bool muted;

  IconData _iconData() {
    switch (actionType) {
      case AutomationHeaderActionType.voice:
        return muted ? CupertinoIcons.speaker_slash : CupertinoIcons.speaker_2;
      case AutomationHeaderActionType.mic:
        return CupertinoIcons.mic;
      case AutomationHeaderActionType.devTools:
        return CupertinoIcons.chevron_left_slash_chevron_right;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active == true ? scheme.primary : scheme.onSurface;
    final duration =
        MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.of(context).accessibleNavigation
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      toggled: active,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          highlightShape: BoxShape.circle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            child: Center(
              child: AnimatedOpacity(
                duration: duration,
                opacity: onTap == null ? 0.38 : 1.0,
                child: Icon(
                  _iconData(),
                  size: 22,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
