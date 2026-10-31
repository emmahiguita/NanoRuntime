/// AUTOMATION-DASHBOARD-CONTENT — Contenido scrolleable del dashboard de Automatización.
///
/// QUÉ HACE:
/// Ensambla la jerarquía visual de la pantalla: header con identidad y controles,
/// tarjeta de ejecución contextual reactiva, y secciones principales (Banner, Agentes, Herramientas).
///
/// CÓMO FUNCIONA:
/// Aplica márgenes de 16/20dp y se coordina con la reserva de NanoDockViewport sin duplicar padding.
///
/// POR QUÉ:
/// Cumple la regla de arquitectura limpia, código < 200 líneas y cero solapamiento con la navegación.
library;

import 'package:flutter/material.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/automation_result.dart';
import '../automation_layout.dart';
import 'automation_active_card.dart';
import 'automation_compact_status.dart';
import 'automation_agent_header.dart';
import 'automation_dashboard_actions.dart';
import 'automation_history_panel.dart';

class AutomationDashboardContent extends StatelessWidget {
  const AutomationDashboardContent({
    super.key,
    required this.settings,
    required this.running,
    required this.lastStatus,
    required this.lastGoal,
    required this.lastReason,
    this.compactExecution = false,
    required this.conversationActive,
    required this.rulesCount,
    required this.businessProductsCount,
    required this.isW4bActive,
    required this.onPickMode,
    required this.onToggleVoiceOutput,
    required this.onActivateConversation,
    required this.onRunTask,
    required this.onConfirmTask,
    this.onDevTap,
    this.onMessagesTap,
    this.onPersonalAgentTap,
    this.onBusinessTap,
    this.onRulesTap,
    this.onSettingsTap,
    this.onMcpTap,
    this.onModelsTap,
    this.onAiWebTap,
    this.onBrowserTap,
    this.onChatTap,
    this.onTerminalTap,
    this.onWhatsAppWebTap,
  });

  final SettingsState settings;
  final bool running;
  final bool compactExecution;
  final AutomationResultStatus? lastStatus;
  final String lastGoal;
  final String lastReason;
  final bool conversationActive;
  final int rulesCount;
  final int businessProductsCount;
  final bool isW4bActive;

  final VoidCallback onPickMode;
  final VoidCallback onToggleVoiceOutput;
  final VoidCallback onActivateConversation;
  final ValueChanged<String> onRunTask;
  final VoidCallback? onConfirmTask;
  final VoidCallback? onDevTap;
  final VoidCallback? onMessagesTap;
  final ValueChanged<BuildContext>? onPersonalAgentTap;
  final ValueChanged<BuildContext>? onBusinessTap;
  final VoidCallback? onRulesTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onMcpTap;
  final VoidCallback? onModelsTap;
  final VoidCallback? onAiWebTap;
  final VoidCallback? onBrowserTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onTerminalTap;
  final VoidCallback? onWhatsAppWebTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 380;
    final horizontalPadding = isCompact ? 16.0 : 20.0;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AutomationLayout.contentMaxWidth(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AgentHeaderWidget(
                mode: settings.agentAutomationMode,
                onModeTap: onPickMode,
                onDevTap: onDevTap,
                onVoiceOutputTap: onToggleVoiceOutput,
                isVoiceOutputEnabled: settings.voiceEnabled,
                onConversationTap: onActivateConversation,
                isConversationActive: conversationActive,
                isRunning: running,
                onHistoryTap: () => showAutomationHistory(context),
              ),
              if (running || lastStatus != null) ...[
                const SizedBox(height: NanoSpacing.md),
                if (compactExecution)
                  AutomationCompactStatus(
                    goal: lastGoal,
                    running: running,
                    status: lastStatus,
                    reason: lastReason,
                    onConfirm: onConfirmTask,
                  )
                else
                  ActiveExecutionCard(
                    goal: lastGoal,
                    running: running,
                    status: lastStatus,
                    reason: lastReason,
                    onConfirm: onConfirmTask,
                  ),
              ],
              const SizedBox(height: 18),
              QuickAutomationActions(
                onRun: onRunTask,
                onMessagesTap: onMessagesTap,
                onPersonalAgentTap: onPersonalAgentTap,
                onBusinessTap: onBusinessTap,
                onRulesTap: onRulesTap,
                onSettingsTap: onSettingsTap,
                onMcpTap: onMcpTap,
                onModelsTap: onModelsTap,
                onAiWebTap: onAiWebTap,
                onBrowserTap: onBrowserTap,
                onChatTap: onChatTap,
                onTerminalTap: onTerminalTap,
                onWhatsAppWebTap: onWhatsAppWebTap,
                activeRulesCount: rulesCount,
                businessProductsCount: businessProductsCount,
                isW4bActive: isW4bActive,
                modeLabel: settings.agentAutomationMode.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
