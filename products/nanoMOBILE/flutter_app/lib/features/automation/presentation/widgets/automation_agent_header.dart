// automation_agent_header.dart — Cabecera principal con acciones superiores e Historial.
// QUÉ HACE: Presenta la identidad a la izquierda y botonera con CupertinoIcons e Historial a la derecha.
// CÓMO FUNCIONA: Dimensiones de icono 22dp, historial 17dp, tipografía Inter 12dp y área táctil accesible.
// POR QUÉ: Diseño iOS limpio con escala tipográfica refinada y sin desbordamientos.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/automation_policy.dart';
import '../automation_visual_theme.dart';
import 'automation_header_action.dart';
import 'automation_header_identity.dart';

class AgentHeaderWidget extends StatelessWidget {
  const AgentHeaderWidget({
    super.key,
    required this.mode,
    required this.onModeTap,
    this.onDevTap,
    this.onVoiceOutputTap,
    this.isVoiceOutputEnabled = false,
    this.onConversationTap,
    this.isConversationActive = false,
    this.isRunning = false,
    this.onHistoryTap,
  });

  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final VoidCallback? onDevTap, onVoiceOutputTap, onConversationTap, onHistoryTap;
  final bool isVoiceOutputEnabled, isConversationActive, isRunning;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    final identity = AutomationHeaderIdentity(
      mode: mode,
      onModeTap: onModeTap,
      running: isRunning,
    );

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onVoiceOutputTap != null)
          AutomationHeaderAction(
            label: isVoiceOutputEnabled
                ? 'Silenciar salida de voz'
                : 'Activar salida de voz',
            actionType: AutomationHeaderActionType.voice,
            active: isVoiceOutputEnabled,
            muted: !isVoiceOutputEnabled,
            onTap: onVoiceOutputTap,
          ),
        if (onConversationTap != null)
          AutomationHeaderAction(
            label: isConversationActive
                ? 'Detener conversación por voz'
                : 'Iniciar conversación por voz',
            actionType: AutomationHeaderActionType.mic,
            active: isConversationActive,
            onTap: isRunning && !isConversationActive ? null : onConversationTap,
          ),
        if (onDevTap != null)
          AutomationHeaderAction(
            label: 'Herramientas técnicas',
            actionType: AutomationHeaderActionType.devTools,
            onTap: onDevTap,
          ),
      ],
    );

    final historyButton = onHistoryTap == null
        ? const SizedBox.shrink()
        : Semantics(
            button: true,
            label: 'Historial',
            child: InkResponse(
              onTap: onHistoryTap,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 17,
                      color: visual.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Historial',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: visual.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    historyButton,
                    actionButtons,
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  actionButtons,
                  const SizedBox(height: 2),
                  historyButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
