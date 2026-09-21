part of 'conversation_detail_sheet.dart';

/// [ConversationDetailController]
///
/// QUÉ HACE:
/// Administra el estado de propiedad de la conversación (Humano vs Bot), la transferencia
/// entre agentes especializados y la generación de sugerencias IA locales multimodales.
///
/// CÓMO FUNCIONA:
/// 1. `_toggleOwnership`: Alterna y persiste en SQLite si la conversación está en manos del
///    dueño humano o si Nano AI tiene autorización de responder automáticamente.
/// 2. `_transferAgent`: Cambia el bot/agente asignado (ej: Ventas, Soporte, Personal) migrando
///    únicamente el contexto imprescindible para evitar contaminación cruzada de memoria.
/// 3. `_generateAiSuggestion`: Invoca el `DynamicReplyGenerator` local combinando hechos de
///    negocio reales (precios, despachos, catálogo) con aprendizaje de estilo de Persona.
///
/// POR QUÉ:
/// Desacopla la lógica de control y generación IA de la presentación gráfica, manteniendo
/// cada archivo con una sola responsabilidad y por debajo del límite de 200 líneas.
extension ConversationDetailController on _ConversationDetailSheetState {
  Future<void> _toggleOwnership(bool human) async {
    setState(() => _isHumanOwned = human);
    final store = ref.read(conversationOwnershipStoreProvider);
    await store.load();
    await store.setOwner(
      widget.item.conversationId,
      human ? ConversationOwner.human : ConversationOwner.bot,
    );
    ref.invalidate(conversationHubListProvider);
  }

  Future<void> _transferAgent(ConversationAgentId target) async {
    if (target == _agentId || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Transfiriendo a ${target.displayName}...';
    });
    try {
      final memory = ref
          .read(conversationMemoryStoreProvider)
          .memoryFor(widget.item.conversationId);
      final minimalContext = <String>[
        if (memory?.activeTopic?.isNotEmpty == true)
          'tema=${memory!.activeTopic}',
        if (memory?.unresolvedObligations.isNotEmpty == true)
          'pendiente=${memory!.unresolvedObligations.take(2).join(' | ')}',
      ].join('; ');

      await ref.read(conversationAssignmentStoreProvider).transfer(
            widget.item.conversationId,
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
      final targetNotif = list
          .where(
            (n) =>
                n.text == widget.item.lastMessage ||
                n.sender == widget.item.displayName,
          )
          .firstOrNull;

      final notifObj = targetNotif != null
          ? targetNotif.toNotificationObject()
          : NotificationObject.fromMap({
              'key': 'hub_${widget.item.conversationId}',
              'package': widget.item.packageName,
              'title': widget.item.displayName,
              'text': widget.item.lastMessage,
              'messageText': widget.item.lastMessage,
              'sender': widget.item.displayName,
              'conversationId': widget.item.conversationId,
              'postTime': widget.item.lastAtMs,
              'canReply': true,
            });

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

      final rawMsg = widget.item.lastMessage.trim();
      final businessFacts = ref.read(businessFactsNotifierProvider);
      final generated = dynamicReplyGenerator.generateOptions(
        incomingText: rawMsg,
        facts: businessFacts,
        senderName: widget.item.displayName,
      );
      for (final opt in generated) {
        if (!allOptions.contains(opt)) {
          allOptions.add(opt);
        }
      }

      final uniqueOptions = <String>[];
      for (final opt in allOptions) {
        final clean = opt.trim();
        if (clean.isNotEmpty && !uniqueOptions.contains(clean)) {
          uniqueOptions.add(clean);
        }
        if (uniqueOptions.length >= 6) break;
      }

      if (mounted) {
        setState(() {
          _suggestions = uniqueOptions;
          if (uniqueOptions.isNotEmpty) {
            _inputController.text = uniqueOptions.first;
          }
          _statusText = uniqueOptions.length > 1
              ? '${uniqueOptions.length} opciones generadas'
              : 'Sugerencia generada con catálogo';
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
