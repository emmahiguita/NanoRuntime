/// AUTOMATION-DASHBOARD-CONTENT — Contenido scrolleable del dashboard.
///
/// QUÉ HACE:
/// Ensambla la jerarquía visual de la pantalla: header, card de ejecución activa,
/// 4 pilares unificados de acción y tarjeta de estado del engine local.
///
/// CÓMO FUNCIONA:
/// Recibe el estado reactivo y construye la vista responsiva respetando márgenes seguros.
///
/// POR QUÉ:
/// Desacopla la vista de la máquina de estados manteniendo cada archivo < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart';
import '../../domain/automation_result.dart';
import '../automation_layout.dart';
import 'automation_active_card.dart';
import 'automation_agent_header.dart';
import 'automation_dashboard_actions.dart';
import 'engine_status_card.dart';

class AutomationDashboardContent extends StatelessWidget {
  const AutomationDashboardContent({
    super.key,
    required this.settings,
    required this.running,
    required this.lastStatus,
    required this.lastGoal,
    required this.lastReason,
    required this.conversationActive,
    required this.pendingDraftsCount,
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
    this.onBotStudioTap,
    this.onSkillsMcpTap,
    this.onTimeRuleTap,
  });

  final SettingsState settings;
  final bool running;
  final AutomationResultStatus? lastStatus;
  final String lastGoal;
  final String lastReason;
  final bool conversationActive;
  final int pendingDraftsCount;
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
  final VoidCallback? onPersonalAgentTap;
  final VoidCallback? onBusinessTap;
  final VoidCallback? onRulesTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onBotStudioTap;
  final VoidCallback? onSkillsMcpTap;
  final VoidCallback? onTimeRuleTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, kNanoBarScrollReserve),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AutomationLayout.contentMaxWidth(context)),
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
              ),
              if (running || lastStatus != null) ...[
                const SizedBox(height: NanoSpacing.lg),
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
                onBotStudioTap: onBotStudioTap,
                onSkillsMcpTap: onSkillsMcpTap,
                onTimeRuleTap: onTimeRuleTap,
                pendingDraftsCount: pendingDraftsCount,
                activeRulesCount: rulesCount,
                businessProductsCount: businessProductsCount,
                isW4bActive: isW4bActive,
                modeLabel: settings.agentAutomationMode.label,
              ),
              const SizedBox(height: 20),
              const EngineStatusCard(cleanAppearance: true),
            ],
          ),
        ),
      ),
    );
  }
}
