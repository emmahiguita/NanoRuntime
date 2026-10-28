// QUÉ: cabecera principal con marca, autonomía y tres acciones reales.
// CÓMO: separa identidad de controles y reutiliza los callbacks existentes.
// POR QUÉ: elimina símbolos ambiguos y desenfoques por botón sin cambiar funciones.
import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../domain/automation_policy.dart';
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
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final VoidCallback? onDevTap, onVoiceOutputTap, onConversationTap;
  final bool isVoiceOutputEnabled, isConversationActive, isRunning;

  @override
  Widget build(BuildContext context) {
    final identity = AutomationHeaderIdentity(
      mode: mode,
      onModeTap: onModeTap,
      running: isRunning,
    );
    final actions = <Widget>[
      if (onVoiceOutputTap != null)
        AutomationHeaderAction(
          label: isVoiceOutputEnabled
              ? 'Silenciar salida de voz'
              : 'Activar salida de voz',
          type: FeatherCoreType.voice,
          active: isVoiceOutputEnabled,
          muted: !isVoiceOutputEnabled,
          onTap: onVoiceOutputTap,
        ),
      if (onConversationTap != null)
        AutomationHeaderAction(
          label: isConversationActive
              ? 'Detener conversación por voz'
              : 'Iniciar conversación por voz',
          type: FeatherCoreType.mic,
          active: isConversationActive,
          // Detener sigue disponible; iniciar durante una tarea ya era rechazado.
          onTap: isRunning && !isConversationActive ? null : onConversationTap,
        ),
      if (onDevTap != null)
        AutomationHeaderAction(
          label: 'Herramientas técnicas',
          type: FeatherCoreType.devTools,
          onTap: onDevTap,
        ),
    ];
    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En paneles estrechos o con letra ampliada, no comprime los blancos táctiles.
          final stacked =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(children: actions),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 6),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderGlassButton extends StatelessWidget {
  const _HeaderGlassButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: SizedBox.square(
            dimension: 44,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: visual.surface.withValues(
                    alpha: visual.isDark ? 0.42 : 0.48,
                  ),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: Colors.white.withValues(
                        alpha: visual.isDark ? 0.13 : 0.58,
                      ),
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: Center(child: icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
