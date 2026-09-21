part of 'conversation_detail_sheet.dart';

/// [ConversationDetailSender]
///
/// QUÉ HACE:
/// Despacha mensajes hacia WhatsApp de forma dual y segura:
/// 1. Vía `RemoteInput` (Notificación nativa en 2do plano sin abrir WhatsApp).
/// 2. Vía `WhatsAppMediaShare` con retorno flash o mediante accesibilidad guiada.
/// Registra auto-aprendizaje de estilo en SQLite FTS4 y deduplica eventos.
///
/// CÓMO FUNCIONA:
/// 1. Resuelve primero si existe una notificación de respuesta activa en el sistema.
/// 2. Si no existe, invoca [ConversationPhoneResolver] para recuperar con certeza los
///    dígitos del contacto evitando abrir chats a ciegas o destinos erróneos.
/// 3. Guarda el mensaje saliente en memoria SQLite (`ConversationMemoryStore`).
/// 4. Si el mensaje es una corrección sobre una sugerencia de Nano, entrena la Persona
///    con el par de aprendizaje respectivo para no repetir el error.
///
/// POR QUÉ:
/// Cumple la regla de enviar mensajes a cualquier contacto real de WhatsApp sin salir de Nano,
/// eliminando simulaciones y manteniendo la seguridad de confirmación.
extension ConversationDetailSender on _ConversationDetailSheetState {
  Future<void> _sendReply() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Enviando mensaje...';
    });
    try {
      if (widget.item.hasPendingReply && widget.item.pendingReplyId != null) {
        final pendingStore = ref.read(pendingReplyStoreProvider);
        await pendingStore.updateDraftText(widget.item.pendingReplyId!, text);
        await pendingStore.approve(widget.item.pendingReplyId!);
      }

      final executor = ref.read(notificationExecutorProvider);
      final list = await executor.list(limit: 50);
      final targetNotif = _findMatchingNotification(list, requireCanReply: true);

      if (targetNotif != null) {
        final replyResult = await executor.confirmAndReply(targetNotif, text);
        if (mounted) {
          setState(() {
            _inputController.clear();
            _statusText = replyResult.isAccepted
                ? 'Mensaje entregado en 2do plano sin abrir WhatsApp'
                : 'No se pudo entregar en 2do plano: ${replyResult.code}';
          });
        }
      } else {
        const share = WhatsAppMediaShare();
        final hasA11y = await share.isAccessibilityEnabled();
        final memoryStore = ref.read(conversationMemoryStoreProvider);
        final personaContext = ref.read(personaContextProvider);
        final whatsAppContacts = ref.read(allWhatsAppContactsProvider).value;

        final phoneDigits = ConversationPhoneResolver.resolve(
          conversationId: widget.item.conversationId,
          displayName: widget.item.displayName,
          lastMessage: widget.item.lastMessage,
          store: memoryStore,
          personaContext: personaContext,
          deviceContacts: whatsAppContacts,
        );

        if (phoneDigits == null || phoneDigits.length < 7) {
          if (mounted) {
            setState(() {
              _statusText = 'Sin notificación activa ni teléfono para ${widget.item.displayName}.';
            });
            await _showMissingPhoneDialog(context, widget.item.displayName);
          }
          return;
        }

        final contact = phoneDigits;

        if (hasA11y) {
          if (mounted) {
            setState(() => _statusText = '⚡ Despachando con retorno automático...');
          }
          final ok = await share.openChat(
            contact: contact,
            text: text,
            packageName: widget.item.packageName,
            autoSend: true,
          );
          if (mounted) {
            setState(() {
              _inputController.clear();
              _statusText = ok
                  ? 'Mensaje despachado y retornado a Nano'
                  : 'No se pudo abrir el chat de WhatsApp';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _busy = false;
              _statusText = 'Acción requerida para enviar sin salir de Nano';
            });
            final action = await _showNoA11yOptionsModal(context, share, contact, text);
            if (action == 'sent_whatsapp' && mounted) {
              setState(() {
                _inputController.clear();
                _statusText = 'Chat abierto en WhatsApp';
              });
            }
            return;
          }
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final memoryStore = ref.read(conversationMemoryStoreProvider);
      memoryStore.appendOutbound(
        widget.item.conversationId,
        text,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: nowMs,
      );
      ref.read(eventDedupeStoreProvider).recordVerifiedOutbound(
        widget.item.conversationId,
        text,
        atMs: nowMs,
      );

      // Autoaprendizaje de estilo en SQLite FTS4
      await _recordStyleLearning(text);

      ref.invalidate(conversationHubListProvider);
      ref.read(conversationHubVersionProvider.notifier).state++;

      if (widget.item.hasPendingReply && widget.item.pendingReplyId != null) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Error enviando mensaje: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordStyleLearning(String text) async {
    final lastMsg = widget.item.lastMessage.trim();
    final isRealIncoming = lastMsg.isNotEmpty && !RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
    if (!isRealIncoming) return;

    try {
      final originalDraft = widget.item.pendingReplyText?.trim();
      final isCorrection = originalDraft != null &&
          originalDraft.isNotEmpty &&
          originalDraft != text;

      await PersonaRepository.instance.addExample(
        personaKey: 'owner',
        incomingText: lastMsg,
        body: text,
        source: isCorrection ? 'correction' : 'messaging_center_learning',
        tone: {
          'ownerVerified': 'true',
          'kind': 'paired',
          if (isCorrection) 'correctedFrom': originalDraft,
        },
      );

      if (isCorrection) {
        await PersonaRepository.instance.savePersonalMemory(
          PersonalMemory(
            scopeKey: 'owner',
            key: 'correccion_estilo',
            value: 'Preferir "$text" sobre "$originalDraft"',
            kind: 'stylePreference',
            observedAt: DateTime.now().millisecondsSinceEpoch,
            metadata: {
              'suggested': originalDraft,
              'corrected': text,
              'input': lastMsg,
            },
          ),
        );
      }
    } catch (_) {}
  }
}
