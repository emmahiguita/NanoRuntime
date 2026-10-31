part of 'conversation_detail_sheet.dart';

/// [ConversationDetailSender]
///
/// QUÉ HACE:
/// Despacha mensajes hacia WhatsApp de forma dual y segura:
/// 1. Vía RemoteInput (Notificación nativa en 2do plano sin abrir WhatsApp).
/// 2. Vía inyección directa en WhatsApp por Accesibilidad o apertura con borrador.
/// Registra auto-aprendizaje de estilo en SQLite FTS4 y deduplica eventos.
///
/// CÓMO FUNCIONA:
/// 1. Si hay notificación activa en el sistema, responde en 2do plano vía RemoteInput.
/// 2. Si no hay notificación en barra, delega la inyección a [ConversationDetailGroupSender]
///    o [ConversationDetailDirectSender], dando por confirmado el destino al existir en el panel.
/// 3. Guarda el mensaje saliente en memoria SQLite (ConversationMemoryStore).
///
/// POR QUÉ:
/// Cumple la regla de inyectar y enviar mensajes a cualquier contacto o grupo real
/// confirmado en el panel de mensajería de Nano sin bloquear al usuario.
extension ConversationDetailSender on _ConversationDetailSheetState {
  Future<void> _sendReply() async {
    if (!mounted) return;
    final text = _inputController.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Enviando mensaje...';
    });
    try {
      final executor = ref.read(notificationExecutorProvider);
      final sentMemory = ref.read(conversationMemoryStoreProvider);
      final dedupe = ref.read(eventDedupeStoreProvider);
      var notificationReplyAccepted = false;
      final conversationId = canonicalConversationId(
        widget.item.conversationId,
      );
      final pendingId = widget.item.hasPendingReply
          ? widget.item.pendingReplyId
          : null;
      final pendingStore = pendingId != null
          ? ref.read(pendingReplyStoreProvider)
          : null;
      if (widget.item.hasPendingReply && widget.item.pendingReplyId != null) {
        await pendingStore!.updateDraftText(pendingId!, text);
      }

      if (!mounted) return;
      final list = await executor.list(limit: 50);
      if (!mounted) return;
      final targetNotif = _findMatchingNotification(
        list,
        requireCanReply: true,
      );

      if (targetNotif != null) {
        final replyResult = await executor.confirmAndReply(targetNotif, text);
        if (!replyResult.isAccepted) {
          if (mounted) {
            setState(() {
              _statusText =
                  'No se pudo enviar: ${replyResult.reason ?? replyResult.code}';
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _inputController.clear();
            _statusText = 'WhatsApp aceptó el mensaje en segundo plano';
          });
        }
        notificationReplyAccepted = true;
      } else {
        const share = WhatsAppMediaShare();
        final hasA11y = await share.isAccessibilityEnabled();
        if (!mounted) return;

        if (widget.item.isGroup) {
          final groupSent = await _sendToGroupFallback(
            text: text,
            share: share,
            hasA11y: hasA11y,
          );
          if (groupSent) {
            notificationReplyAccepted = true;
          } else {
            // H2: Se abrió WhatsApp o se requirió intervención; no marcar como enviado
            return;
          }
        } else {
          final directSent = await _sendDirectFallback(
            text: text,
            share: share,
            hasA11y: hasA11y,
            conversationId: conversationId,
          );
          if (directSent) {
            notificationReplyAccepted = true;
          } else {
            // H2: Se abrió WhatsApp o se requirió intervención; no marcar como enviado
            return;
          }
        }
      }

      if (!notificationReplyAccepted) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      sentMemory.appendOutbound(
        conversationId,
        text,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: nowMs,
      );
      dedupe.recordVerifiedOutbound(conversationId, text, atMs: nowMs);

      if (mounted) await _recordStyleLearning(text);

      if (pendingId != null) {
        await pendingStore!.markSent(pendingId);
      }

      if (mounted) {
        ref.invalidate(conversationHubListProvider);
        ref.read(conversationHubVersionProvider.notifier).state++;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Error enviando mensaje: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}