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
            child: Icon(Icons.auto_mode_rounded, size: 20, color: visual.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text(
                  'Automatización',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: visual.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
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
              ],
            ),
          ),
          if (onVoiceOutputTap != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onVoiceOutputTap,
              icon: Icon(
                isVoiceOutputEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: isVoiceOutputEnabled
                    ? visual.accent
                    : (visual.isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : visual.textMuted),
                size: 20,
              ),
            ),
          if (onConversationTap != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onConversationTap,
              icon: Icon(
                isConversationActive
                    ? Icons.record_voice_over_rounded
                    : Icons.voice_chat_outlined,
                color: isConversationActive
                    ? visual.accent
                    : (visual.isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : visual.textMuted),
                size: 20,
              ),
            ),
          if (onDevTap != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onDevTap,
              icon: Icon(
                Icons.smart_toy_outlined,
                color: visual.accent,
                size: 21,
              ),
            ),
        ],
      ),
    );
  }
}
