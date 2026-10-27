part of 'conversation_detail_sheet.dart';

/// Gestiona el dueño del chat, la transferencia de agente y sugerencias.
/// Cada acción persiste su estado y usa el compositor de respuestas real.
extension ConversationDetailController on _ConversationDetailSheetState {
  // Repara al reabrir la conversación el vínculo Bot → regla de notificación.
  void _restoreWhatsAppAutomation() {
    if (_isHumanOwned) return;
    unawaited(
      _ensureWhatsAppRule().catchError((Object error) {
        if (mounted) setState(() => _statusText = 'IA no activada: $error');
      }),
    );
  }

  Future<void> _toggleOwnership(bool human) async {
    if (!mounted) return;
    if (human) _suggestionBudget?.cancel();
    final previous = _isHumanOwned;
    setState(() {
      _isHumanOwned = human;
      _statusText = human
          ? 'Activando control humano...'
          : 'Devolviendo el control a Nano...';
    });
    try {
      final newOwner = human ? ConversationOwner.human : ConversationOwner.bot;
      // Lista y detalle comparten bloqueo, aliases, invalidación y persistencia.
      await ref
          .read(conversationHubActionControllerProvider)
          .setOwnership(widget.item, newOwner);
      if (!mounted) return;
      setState(() {
        _statusText = human
            ? 'Control humano activo. Puedes escribir y enviar directamente.'
            : 'IA activa para esta conversación.';
      });
      ref.invalidate(conversationHubListProvider);
      ref.invalidate(allHubConversationsProvider);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        // Al fallar una escritura, el store deja el chat cerrado al bot.
        _isHumanOwned = human || previous;
        _statusText = 'No se pudo cambiar el control: $error';
      });
    }
  }

  // Sincroniza el Bot visible con la regla que admite notificaciones reales.
  Future<void> _ensureWhatsAppRule() async {
    await ref
        .read(conversationHubActionControllerProvider)
        .ensureWhatsAppReady(widget.item.packageName);
  }

  Future<void> _transferAgent(ConversationAgentId target) async {
    if (!mounted || target == _agentId || _busy) return;
    final conversationId = canonicalConversationId(widget.item.conversationId);
    setState(() {
      _busy = true;
      _statusText = 'Transfiriendo a ${target.displayName}...';
    });
    try {
      final memory = ref
          .read(conversationMemoryStoreProvider)
          .memoryFor(conversationId);
      final minimalContext = <String>[
        if (memory?.activeTopic?.isNotEmpty == true)
          'tema=${memory!.activeTopic}',
        if (memory?.unresolvedObligations.isNotEmpty == true)
          'pendiente=${memory!.unresolvedObligations.take(2).join(' | ')}',
      ].join('; ');

      await ref
          .read(conversationAssignmentStoreProvider)
          .transfer(
            conversationId,
            target,
            reason: 'transferencia explícita desde Centro de Conversaciones',
            minimalContext: minimalContext,
          );

      if (!mounted) return;
      setState(() {
        _agentId = target;
        _statusText = 'Transferida a ${target.displayName}. Memoria aislada.';
      });
      ref.invalidate(conversationHubListProvider);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _statusText = 'No se pudo transferir: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Solicita borradores reales sin consumir deduplicación ni enviar al contacto.
  Future<void> _generateAiSuggestion() async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Generando borrador con el modelo configurado...';
    });
    // La hoja es dueña de esta solicitud y la cancela en dispose.
    final budget = ExecutionBudget(const Duration(seconds: 180));
    _suggestionBudget = budget;
    try {
      final executor = ref.read(notificationExecutorProvider);
      final composer = ref.read(conversationReplyComposerProvider);

      final list = await executor.list(limit: 50);
      if (!mounted) return;
      // Reutiliza identidad/aliases y paquete: nunca basta un nombre parecido.
      final targetNotif = _findMatchingNotification(list);

      final notifObj = targetNotif != null
          ? targetNotif.toNotificationObject()
          : notificationFromConversationSummary(
              widget.item,
              latestInbound: _liveEntries
                  .where(
                    (entry) =>
                        entry.kind == ConversationMemoryEntryKind.inbound,
                  )
                  .lastOrNull,
            );

      final allOptions = await budget.run(
        () => composer.composeSuggestions(notifObj),
      );
      final uniqueOptions = allOptions
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toSet()
          .take(3)
          .toList();

      if (mounted) {
        setState(() {
          _suggestions = uniqueOptions;
          // No sobrescribe un texto que el dueño ya estaba redactando.
          if (uniqueOptions.isNotEmpty &&
              _inputController.text.trim().isEmpty) {
            _inputController.text = uniqueOptions.first;
          }
          _statusText = uniqueOptions.isEmpty
              ? 'El modelo no devolvió un borrador utilizable. Revisa su estado.'
              : uniqueOptions.length > 1
              ? '${uniqueOptions.length} opciones contextuales'
              : '1 opción contextual';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'No se pudo generar borrador: $e');
      }
    } finally {
      budget.cancel();
      if (identical(_suggestionBudget, budget)) _suggestionBudget = null;
      if (mounted) setState(() => _busy = false);
    }
  }
}
