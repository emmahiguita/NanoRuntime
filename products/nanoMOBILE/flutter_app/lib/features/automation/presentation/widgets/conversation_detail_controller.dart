part of 'conversation_detail_sheet.dart';

/// Gestiona el dueño del chat, la transferencia de agente y sugerencias.
/// Cada acción persiste su estado y usa el compositor de respuestas real.
extension ConversationDetailController on _ConversationDetailSheetState {
  // Repara al reabrir la conversación el vínculo Bot → regla de notificación.
  void _restoreWhatsAppAutomation() {
    if (_isHumanOwned) return;
    unawaited(_ensureWhatsAppRule().catchError((Object error) {
      if (mounted) setState(() => _statusText = 'IA no activada: $error');
    }));
  }

  Future<void> _toggleOwnership(bool human) async {
    final previous = _isHumanOwned;
    setState(() {
      _isHumanOwned = human;
      _statusText = human
          ? 'Activando control humano...'
          : 'Devolviendo el control a Nano...';
    });
    try {
      final store = ref.read(conversationOwnershipStoreProvider);
      await store.load();
      final newOwner = human ? ConversationOwner.human : ConversationOwner.bot;
      // El merger conserva únicamente aliases cuya equivalencia técnica ya
      // fue demostrada. Persistirlos evita que Android cambie de shortcut y
      // vuelva a dejar el chat como no seleccionado.
      final conversationIds = <String>{
        canonicalConversationId(widget.item.conversationId),
        ...widget.item.conversationAliases.map(canonicalConversationId),
      }..removeWhere((id) => id.isEmpty);
      if (conversationIds.isEmpty) {
        throw StateError('La conversación no tiene identidad técnica');
      }
      // Evita guardar ownership Bot si no pudo quedar activo su disparador.
      if (!human) await _ensureWhatsAppRule();
      for (final conversationId in conversationIds) {
        await store.setOwner(conversationId, newOwner);
      }
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
        _isHumanOwned = previous;
        _statusText = 'No se pudo cambiar el control: $error';
      });
    }
  }

  // Sincroniza el Bot visible con la regla que admite notificaciones reales.
  Future<void> _ensureWhatsAppRule() async {
    final packageName = widget.item.packageName;
    if (packageName != MessagingPackage.whatsapp &&
        packageName != MessagingPackage.whatsappBusiness) {
      return;
    }
    final registry = ref.read(ruleRegistryProvider);
    await registry.load();
    registry.seedWhatsAppRule(packageName);
    await registry.flush();
  }

  Future<void> _transferAgent(ConversationAgentId target) async {
    if (target == _agentId || _busy) return;
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

  Future<void> _generateAiSuggestion() async {
    setState(() {
      _busy = true;
      _statusText = 'Generando opciones con IA local...';
    });
    try {
      final executor = ref.read(notificationExecutorProvider);
      final composer = ref.read(conversationReplyComposerProvider);

      final list = await executor.list(limit: 10);
      final expectedKey = (widget.item.notificationKey ?? '').trim();
      final expectedConversation = canonicalConversationId(
        widget.item.conversationId,
      );
      // La identidad visible puede repetirse. Solo una key exacta o la
      // identidad técnica resuelta puede seleccionar la notificación activa.
      final targetNotif = list.where((notification) {
        if (expectedKey.isNotEmpty && notification.key == expectedKey) {
          return true;
        }
        final resolved = resolveConversationIdentity(
          notification.toNotificationObject(),
        ).key.id;
        return resolved.isNotEmpty &&
            canonicalConversationId(resolved) == expectedConversation;
      }).firstOrNull;

      final notifObj = targetNotif != null
          ? targetNotif.toNotificationObject()
          : notificationFromConversationSummary(widget.item);

      final draftResult = await composer.compose(notifObj);
      final allOptions = <String>[];

      if (draftResult != null && draftResult.hasReply) {
        allOptions.add(draftResult.text.trim());
        for (final s in draftResult.suggestions) {
          final clean = s.trim();
          if (clean.isNotEmpty && !allOptions.contains(clean)) {
            allOptions.add(clean);
          }
        }
      }

      // El generador local no interpreta conversación personal: únicamente
      // agrega opciones si FactSelection encontró catálogo real aplicable.
      final rawMsg = widget.item.lastMessage.trim();
      final businessFacts = ref.read(businessFactsNotifierProvider);
      final generated =
          _agentId == ConversationAgentId.business && !businessFacts.isEmpty
          ? dynamicReplyGenerator.generateOptions(
              incomingText: rawMsg,
              facts: businessFacts,
            )
          : const <String>[];
      allOptions.addAll(generated.where((opt) => !allOptions.contains(opt)));
      final uniqueOptions = allOptions
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toSet()
          .take(6)
          .toList();

      if (mounted) {
        setState(() {
          _suggestions = uniqueOptions;
          if (uniqueOptions.isNotEmpty) {
            _inputController.text = uniqueOptions.first;
          }
          _statusText = uniqueOptions.isEmpty
              ? 'Sin respuesta fiable. Instala o activa un modelo real.'
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
      if (mounted) setState(() => _busy = false);
    }
  }
}
