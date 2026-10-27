// conversation_detail_library.dart
//
// QUÉ HACE:
// Conecta el detalle de la conversación con la biblioteca comercial de Nano y el despacho a WhatsApp.
//
// CÓMO FUNCIONA:
// - Resuelve la identidad verificada del destinatario (número o shortcut de grupo).
// - Despliega BusinessDocumentLibraryDialog con selector y callback onSendToChat.
// - Transfiere los archivos mediante WhatsAppMediaShare respetando la accesibilidad y retorno automático.
//
// POR QUÉ:
// Centraliza el despacho de archivos comerciales respetando SOLID y la regla de < 200 líneas.

part of 'conversation_detail_sheet.dart';

extension ConversationDetailLibrary on _ConversationDetailSheetState {
  ({String contact, String name, String kind, bool verified})?
  _verifiedAttachmentRecipient() {
    final packageName = widget.item.packageName.toLowerCase();
    final rawName = widget.item.groupTitle?.trim().isNotEmpty == true
        ? widget.item.groupTitle!
        : widget.item.displayName;
    final name = _cleanName(rawName);
    if (!packageName.contains('whatsapp') || name.isEmpty) return null;

    if (widget.item.isGroup) {
      // Un título o hash visual no identifica un grupo de WhatsApp. Solo el
      // JID oficial permite preseleccionarlo sin riesgo de abrir otro chat.
      final groupJid = widget.item.conversationId.trim();
      if (!groupJid.toLowerCase().endsWith('@g.us')) return null;
      return (contact: groupJid, name: name, kind: 'group', verified: true);
    }

    final phone = ConversationPhoneResolver.resolve(
      conversationId: canonicalConversationId(widget.item.conversationId),
      displayName: name,
      lastMessage: widget.item.lastMessage,
      store: ref.read(conversationMemoryStoreProvider),
      personaContext: ref.read(personaContextProvider),
      deviceContacts: ref.read(allWhatsAppContactsProvider).value,
    );
    // Fallo cerrado: el nombre visible jamás se convierte en identidad
    // verificada. Sin número real, el usuario debe elegir el chat en WhatsApp.
    if (phone == null || phone.length < 7) return null;
    return (contact: phone, name: name, kind: 'direct', verified: true);
  }

  Future<void> _showNanoLibrary() async {
    await ref.read(businessFactsNotifierProvider.notifier).ready;
    if (!mounted) return;
    final facts = ref.read(businessFactsNotifierProvider);
    await BusinessDocumentLibraryDialog.show(
      context,
      facts,
      onSendToChat: _shareBusinessDocuments,
    );
  }

  Future<void> _shareBusinessDocuments(List<BusinessDocument> docs) async {
    // La biblioteca puede seguir abierta cuando el chat original ya se cerró.
    if (!mounted || docs.isEmpty || _busy) return;
    final caption = _inputController.text.trim();
    _safeSetState(() {
      _busy = true;
      _statusText = docs.length == 1
          ? 'Preparando ${docs.first.name}...'
          : 'Preparando ${docs.length} archivos...';
    });
    try {
      final recipient = _verifiedAttachmentRecipient();
      if (recipient == null) {
        _safeSetState(
          () => _statusText =
              'No hay una identidad verificable para ${widget.item.displayName}.',
        );
        return;
      }
      const share = WhatsAppMediaShare();
      final returnsToNano = await share.isAccessibilityEnabled();
      bool ok = true;
      for (final doc in docs) {
        // No inicia el siguiente envío desde una pantalla desmontada.
        if (!mounted) return;
        final success = await share.shareFile(
          path: doc.file.path,
          contact: recipient.contact,
          caption: caption,
          packageName: widget.item.packageName,
          autoSend: true,
          recipientName: recipient.name,
          recipientKind: recipient.kind,
          recipientVerified: recipient.verified,
        );
        if (!success) ok = false;
      }
      _safeSetState(
        () => _statusText = !ok
            ? 'No se pudieron enviar algunos archivos.'
            : returnsToNano
            ? 'Automatización iniciada. Nano regresará tras pulsar Enviar.'
            : 'Archivo(s) abierto(s) en WhatsApp. Confirma Enviar allí para completar.',
      );
    } catch (_) {
      _safeSetState(
        () => _statusText =
            'No se pudieron compartir los archivos. Intenta de nuevo.',
      );
    } finally {
      _safeSetState(() => _busy = false);
    }
  }
}
