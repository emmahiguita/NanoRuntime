/// AUTOMATION-DASHBOARD — Centro de control operativo de Nano AI.
///
/// QUÉ HACE:
/// Orquesta la interfaz del asistente: composer cósmico, voz push-to-talk,
/// tareas activas y las 4 áreas unificadas (Inbox, Personal, Negocio, Sistema).
///
/// CÓMO FUNCIONA:
/// Conecta [NanoInputScope] al árbol de widgets y delega en controladores modulares.
///
/// POR QUÉ:
/// Cumple estrictamente con el límite de < 200 líneas garantizando alta cohesión.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../../../core/widgets/navigation/nano_universal_input.dart';
import '../../application/automation_coordinator_provider.dart'
    show pendingRepliesProvider, ruleRegistryProvider;
import '../../application/automation_diagnostics.dart';
import '../../application/automation_engine.dart';
import '../../application/automation_engine_provider.dart';
import '../../application/automation_feedback_presenter.dart';
import '../../application/rule_creator.dart';
import '../../domain/automation_result.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/governance/action_confirmation.dart';
import '../../engine/messaging/messaging_package.dart';
import '../../engine/voice/voice_runtime.dart';
import 'automation_dashboard_content.dart';
import 'automation_dashboard_dialogs.dart';
import 'automation_dashboard_runner.dart';
import 'automation_dashboard_voice.dart';
import 'automation_dashboard_voice_controller.dart';
export 'automation_engine_status_provider.dart';

class AutomationDashboard extends ConsumerStatefulWidget {
  const AutomationDashboard({
    super.key,
    this.onSettingsTap,
    this.onMessagesTap,
    this.onRulesTap,
    this.onBusinessTap,
    this.onPersonalAgentTap,
    this.onBotStudioTap,
    this.onSkillsMcpTap,
    this.onDevTap,
  });

  final VoidCallback? onSettingsTap, onMessagesTap, onRulesTap;
  final VoidCallback? onBusinessTap, onPersonalAgentTap, onBotStudioTap;
  final VoidCallback? onSkillsMcpTap, onDevTap;

  @override
  ConsumerState<AutomationDashboard> createState() => _AutomationDashboardState();
}

class _AutomationDashboardState extends ConsumerState<AutomationDashboard> {
  late final AutomationVoiceController _voiceCtrl;
  StreamSubscription<VoiceSessionState>? _voiceSub;
  StreamSubscription<String>? _confirmSub;
  AutomationResultStatus? _lastStatus;
  String _lastGoal = '';
  String _lastReason = '';
  bool _running = false;
  String? _activeExecutionId;
  AutomationEngine? _activeEngine;
  ActionConfirmation? _lastConfirmation;

  @override
  void initState() {
    super.initState();
    final vs = ref.read(chatProvider.notifier).voiceSession;
    _voiceCtrl = AutomationVoiceController(
      voiceSession: vs,
      isRunning: () => _running,
      isSensing: () => vs.state == VoiceSessionState.listening || vs.state == VoiceSessionState.processing,
      onFeedback: (fb) { if (mounted) setState(() {}); },
    );
    _voiceSub = vs.states.listen((_) { if (mounted) setState(() {}); });
    _confirmSub = NanoRuntimeApi.instance.automationConfirmationActions.listen((action) {
      if (action == 'confirm' && mounted && !_running && _lastConfirmation != null) {
        unawaited(_runTask(_lastGoal, confirmation: _lastConfirmation));
      }
    });
  }

  @override
  void dispose() {
    _voiceSub?.cancel(); _confirmSub?.cancel();
    super.dispose();
  }

  Future<AutomationResult?> _runTask(
    String text, {
    ActionConfirmation? confirmation,
    bool fromVoice = false,
    bool speakResult = true,
  }) async {
    final goal = text.trim();
    if (goal.isEmpty || _running) return null;
    final executionId = confirmation?.executionId ?? 'dash-${UniqueKey()}';
    _activeEngine = ref.read(automationEngineProvider);
    _activeExecutionId = executionId;
    setState(() { _running = true; _lastGoal = goal; _lastStatus = null; _lastReason = ''; });

    final result = await AutomationDashboardRunner.execute(
      text: goal,
      engine: _activeEngine!,
      diagnostics: ref.read(automationDiagnosticsProvider),
      confirmation: confirmation,
      executionId: executionId,
    );

    if (mounted && result != null) {
      setState(() {
        _lastStatus = result.status;
        _lastReason = automationUserFacingReason(result.reason);
        _lastConfirmation = result.confirmation;
        _running = false;
      });
      if (result.status == AutomationResultStatus.paused && result.confirmation != null) {
        unawaited(NanoRuntimeApi.instance.showAutomationConfirmation());
      }
      if (ref.read(settingsProvider).voiceEnabled && speakResult && !isDiagCommand(goal)) {
        await ref.read(chatProvider.notifier).voiceSession.respond(
          AutomationDashboardRunner.spokenResult(result),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final drafts = ref.watch(pendingRepliesProvider).maybeWhen(
      data: (list) => list.where((d) => d.isActionable).length,
      orElse: () => 0,
    );
    final rules = ref.watch(ruleRegistryProvider);
    final isW4b = rules.isWhatsAppRuleActive(MessagingPackage.whatsappBusiness);

    return NanoInputScope(
      scopeId: 'automation',
      hint: 'Describe qué quieres automatizar en Nano AI...',
      onSubmit: (t) => _runTask(t),
      onVoice: () => _voiceCtrl.activateVoice(onGoalRecognized: (g) => _runTask(g, fromVoice: true)),
      onAttach: () => _voiceCtrl.observeScreen(situationSource: () => ref.read(currentSituationSourceProvider).call()),
      isGenerating: _running,
      onStop: _running && _activeExecutionId != null ? () => _activeEngine?.cancelExecution(_activeExecutionId!) : null,
      child: AutomationDashboardContent(
        settings: settings,
        running: _running,
        lastStatus: _lastStatus,
        lastGoal: _lastGoal,
        lastReason: _lastReason,
        conversationActive: _voiceCtrl.conversationActive,
        pendingDraftsCount: drafts,
        rulesCount: rules.rules.where((r) => r.enabled).length,
        businessProductsCount: ref.watch(businessFactsNotifierProvider).products.length,
        isW4bActive: isW4b,
        onPickMode: () => AutomationDashboardDialogs.pickMode(
          context: context, currentMode: settings.agentAutomationMode,
          onSelected: (m) => ref.read(settingsProvider.notifier).setAgentAutomationMode(m),
        ),
        onToggleVoiceOutput: () => AutomationVoiceHandler.toggleVoiceOutput(
          settingsNotifier: ref.read(settingsProvider.notifier),
          currentEnabled: settings.voiceEnabled, onFeedback: (_) => setState(() {}),
        ),
        onActivateConversation: () => _voiceCtrl.activateConversation(
          onTurn: (t) => _runTask(t, fromVoice: true, speakResult: false),
        ),
        onRunTask: (goal) => _runTask(goal),
        onConfirmTask: _lastStatus == AutomationResultStatus.paused
            ? () => _runTask(_lastGoal, confirmation: _lastConfirmation)
            : null,
        onDevTap: widget.onDevTap,
        onMessagesTap: widget.onMessagesTap,
        onPersonalAgentTap: widget.onPersonalAgentTap,
        onBusinessTap: widget.onBusinessTap,
        onRulesTap: widget.onRulesTap,
        onSettingsTap: widget.onSettingsTap,
        onBotStudioTap: widget.onBotStudioTap,
        onSkillsMcpTap: widget.onSkillsMcpTap,
        onTimeRuleTap: () => AutomationDashboardDialogs.createTimeRule(
          context: context, ruleCreator: ref.read(ruleCreatorProvider),
        ),
      ),
    );
  }
}
