// QUÉ: dashboard operativo con entrada contextual de texto y voz.
// CÓMO: conecta el scope y presenta estados reales; ejecución separada en un part.
// POR QUÉ: conserva controles y recursos sin mezclar presentación y despacho.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../../../core/widgets/navigation/nano_universal_input.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart'
    show NanoFloatingNavigationFrame;
import '../../../browser_ai/presentation/sheets/ai_web_sessions_sheet.dart';
import '../whatsapp_web/whatsapp_web_screen.dart';
import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../application/automation_diagnostics.dart';
import '../../application/automation_engine.dart';
import '../../application/whatsapp_ui_goal_preparer.dart';
import '../../domain/prepared_automation_goal.dart';
import '../../engine/planning/whatsapp_component_requests.dart';
import '../../engine/agent_dependencies.dart' show agentExecutorProvider;
import '../../application/automation_engine_provider.dart';
import '../../application/automation_feedback_presenter.dart';
import '../../domain/automation_result.dart';
import '../../engine/execution/agent_tool_dispatcher.dart'
    show AgentToolDispatcher;
import '../../engine/business/business_facts_providers.dart';
import '../../engine/governance/action_confirmation.dart';
import '../../engine/messaging/messaging_package.dart';
import '../../engine/voice/voice_runtime.dart';
import 'automation_dashboard_content.dart';
import 'automation_input_context_controller.dart';
import '../../application/automation_access_controller.dart';
import '../../ledger/automation_activity_store.dart';
import 'whatsapp_automation_menu.dart';
import 'automation_input_menu.dart';
import 'automation_input_attachment.dart';
import 'automation_attachment_picker.dart';
import 'automation_dashboard_dialogs.dart';
import 'automation_dashboard_runner.dart';
import 'automation_dashboard_voice.dart';
import 'automation_dashboard_voice_controller.dart';
import 'automation_command_feedback.dart';
export 'automation_engine_status_provider.dart';
part 'automation_dashboard_execution.dart';
part 'automation_dashboard_goal_execution.dart';
part 'automation_dashboard_view.dart';
part 'automation_dashboard_lifecycle.dart';
part 'automation_dashboard_input.dart';

class AutomationDashboard extends ConsumerStatefulWidget {
  const AutomationDashboard({
    super.key,
    this.onSettingsTap,
    this.onMessagesTap,
    this.onRulesTap,
    this.onBusinessTap,
    this.onPersonalAgentTap,
    this.onDevTap,
  });

  final VoidCallback? onSettingsTap, onMessagesTap, onRulesTap;
  // El contexto pertenece a la tarjeta: permite medir su origen, no el dashboard.
  final ValueChanged<BuildContext>? onBusinessTap, onPersonalAgentTap;
  final VoidCallback? onDevTap;

  @override
  ConsumerState<AutomationDashboard> createState() =>
      _AutomationDashboardState();
}

class _AutomationDashboardState extends ConsumerState<AutomationDashboard> {
  late final AutomationVoiceController _voiceCtrl;
  final _inputContext = AutomationInputContextController();
  final _access = AutomationAccessController();
  final _commandController = TextEditingController();
  final _commandFocus = FocusNode();
  bool _cancelRequested = false;
  Future<void>? _inputMenu;
  AutomationInputAttachment? _attachment;
  StreamSubscription<VoiceSessionState>? _voiceSub;
  StreamSubscription<String>? _confirmSub;
  AutomationResultStatus? _lastStatus;
  String _lastGoal = '';
  String _lastReason = '';
  bool _running = false;
  String? _activeExecutionId;
  AutomationEngine? _activeEngine;
  ActionConfirmation? _lastConfirmation;
  ({
    String original,
    String command,
    String id,
    PreparedAutomationGoal goal,
    bool usesAttachment,
  })?
  _pendingGoal;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _stopActiveTask();
    _voiceCtrl.dispose();
    _access.removeListener(_refreshInputContext);
    _access.dispose();
    _commandController.dispose();
    _commandFocus.dispose();
    _inputContext.removeListener(_refreshInputContext);
    _inputContext.dispose();
    _voiceSub?.cancel();
    _confirmSub?.cancel();
    super.dispose();
  }

  /// La extensión de ejecución solicita cambios; el State es dueño de setState.
  void _updateExecutionState(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  Widget build(BuildContext context) => _buildDashboard(context);
}
