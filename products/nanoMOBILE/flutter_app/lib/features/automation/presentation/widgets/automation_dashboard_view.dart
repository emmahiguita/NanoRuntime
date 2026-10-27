part of 'automation_dashboard.dart';

/// Presentación separada del dueño de ejecución y de sus recursos.
extension _DashboardView on _AutomationDashboardState {
  /// Renderiza la misma barra, tarjetas y callbacks del dashboard; no decide ejecución.
  Widget _buildDashboard(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final rules = ref.watch(ruleRegistryProvider);
    final isW4b = rules.isWhatsAppRuleActive(MessagingPackage.whatsappBusiness);

    return NanoInputScope(
      scopeId: 'automation',
      controller: _commandController,
      focusNode: _commandFocus,
      clearOnSubmit: false,
      toolContext: _inputContext.value,
      submitLabel: 'Ejecutar',
      onChanged: _updateInputDraft,
      hint: _inputHint,
      toolControls: NanoInputToolControls(
        name: 'WhatsApp',
        asset: 'assets/automation/whatsapp_personal_icon.png',
        selected: _inputContext.selected,
        onOptions: _openWhatsAppMenu,
        onAdd: _openInputMenu,
        attachmentName: _attachment?.name,
        onRemoveAttachment: _running ? null : _removeAttachment,
        notice: _inputContext.selected && _access.ready != true
            ? 'Accesibilidad necesaria para escribir y enviar'
            : null,
        onConfigure: _access.configure,
      ),
      onSubmit: (t) => _runTask(t),
      onVoice: () => _voiceCtrl.activateVoice(
        onGoalRecognized: (g) => _runTask(g, fromVoice: true),
      ),
      onAttach: _showInputOptions,
      isGenerating: _running,
      onStop: _running && _activeExecutionId != null ? _stopActiveTask : null,
      child: AutomationDashboardContent(
        settings: settings,
        running: _running,
        lastStatus: _lastStatus,
        lastGoal: _lastGoal,
        lastReason: _lastReason,
        compactExecution: _inputContext.value != null,
        conversationActive: _voiceCtrl.conversationActive,
        rulesCount: rules.rules.where((r) => r.enabled).length,
        businessProductsCount: ref
            .watch(businessFactsNotifierProvider)
            .products
            .length,
        isW4bActive: isW4b,
        onPickMode: () => AutomationDashboardDialogs.pickMode(
          context: context,
          currentMode: settings.agentAutomationMode,
          onSelected: (m) =>
              ref.read(settingsProvider.notifier).setAgentAutomationMode(m),
        ),
        onToggleVoiceOutput: () => AutomationVoiceHandler.toggleVoiceOutput(
          settingsNotifier: ref.read(settingsProvider.notifier),
          currentEnabled: settings.voiceEnabled,
          onFeedback: (_) => setState(() {}),
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
        onMcpTap: () => context.push('/automation/skills-mcp'),
        onModelsTap: () => context.push('/models'),
        onAiWebTap: () => AiWebSessionsSheet.show(context),
        onBrowserTap: () => context.push('/browser'),
        onChatTap: () => context.push('/chat'),
        onTerminalTap: () => context.push('/terminal'),
        onWhatsAppWebTap: () => WhatsAppWebScreen.navigateTo(context),
      ),
    );
  }
}
