/// AUTOMATION-AGENT-HEADER — Cabecera de control del asistente.
///
/// QUÉ HACE:
/// Muestra el título del módulo, el badge de autonomía actual y controles de audio/voz.
///
/// CÓMO FUNCIONA:
/// Diseñado de forma compacta con semántica accesible y respuesta táctil.
///
/// POR QUÉ:
/// Centraliza el estado de autonomía sin estorbar el flujo de trabajo del usuario.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import '../../domain/automation_policy.dart';
import '../automation_visual_theme.dart';

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
  final VoidCallback? onDevTap;
  final VoidCallback? onVoiceOutputTap;
  final bool isVoiceOutputEnabled;
  final VoidCallback? onConversationTap;
  final bool isConversationActive;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: visual.accent.withValues(alpha: 0.12),
              border: Border.all(color: visual.accent.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.auto_mode_rounded,
              size: 20,
              color: visual.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                    children: [
                      TextSpan(
                        text: 'NANO ',
                        style: TextStyle(color: visual.text),
                      ),
                      TextSpan(
                        text: 'AI',
                        style: TextStyle(color: visual.accent),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(
                      color: visual.accent.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: onModeTap,
                    borderRadius: BorderRadius.circular(99),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 34),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Center(
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              color: visual.accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onVoiceOutputTap != null)
            _HeaderGlassButton(
              tooltip: isVoiceOutputEnabled ? 'Silenciar voz' : 'Activar voz',
              onTap: onVoiceOutputTap!,
              icon: Icon(
                isVoiceOutputEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: isVoiceOutputEnabled ? visual.accent : visual.textMuted,
                size: 20,
              ),
            ),
          if (onConversationTap != null)
            _HeaderGlassButton(
              tooltip: 'Conversación por voz',
              onTap: onConversationTap!,
              icon: Icon(
                isConversationActive
                    ? Icons.record_voice_over_rounded
                    : Icons.voice_chat_outlined,
                color: isConversationActive ? visual.accent : visual.textMuted,
                size: 20,
              ),
            ),
          if (onDevTap != null)
            _HeaderGlassButton(
              tooltip: 'Herramientas técnicas',
              onTap: onDevTap!,
              icon: Icon(
                Icons.smart_toy_outlined,
                color: visual.textMuted,
                size: 21,
              ),
            ),
        ],
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
