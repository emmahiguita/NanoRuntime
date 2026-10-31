part of 'conversation_detail_sheet.dart';

/// [ConversationDetailDirectSender]
///
/// QUÉ HACE:
/// Despacha mensajes hacia contactos directos de WhatsApp cuando no existe
/// una notificación activa en la barra (RemoteInput).
///
/// CÓMO FUNCIONA:
/// 1. Si la accesibilidad está disponible y WhatsApp está visible, intenta inyección directa.
/// 2. Si no está en pantalla, resuelve el número mediante [ConversationPhoneResolver].
/// 3. Si no hay teléfono pero el chat existe en el panel, abre WhatsApp con el borrador preparado.
///
/// POR QUÉ:
/// Si la conversación ya está confirmada en el panel de mensajería, Nano prioriza
/// la inyección y despacho sin bloquear con advertencias innecesarias.
extension ConversationDetailDirectSender on _ConversationDetailSheetState {
  Future<bool> _sendDirectFallback({
    required String text,
    required WhatsAppMediaShare share,
    required bool hasA11y,
    required String conversationId,
  }) async {
    // 1. Si hay accesibilidad y WhatsApp está en pantalla, intenta inyectar directamente.
    if (hasA11y) {
      final injected = await _tryDirectInjection(text);
      if (injected) {
        if (mounted) {
          setState(() {
            _inputController.clear();
            _statusText = 'Mensaje inyectado y enviado en WhatsApp';
          });
        }
        return true;
      }
    }

    final memoryStore = ref.read(conversationMemoryStoreProvider);
    final personaContext = ref.read(personaContextProvider);
    final whatsAppContacts = ref.read(allWhatsAppContactsProvider).value;

    final phoneDigits = ConversationPhoneResolver.resolve(
      conversationId: conversationId,
      displayName: widget.item.displayName,
      lastMessage: widget.item.lastMessage,
      store: memoryStore,
      personaContext: personaContext,
      deviceContacts: whatsAppContacts,
    );

    // Extrae JID/LID si no hay teléfono directo (ej. chats con privacidad @lid o @s.whatsapp.net)
    String? directJid;
    for (final raw in [conversationId, ...widget.item.conversationAliases]) {
      final match = RegExp(
        r'[\w.\-]+@(s\.whatsapp\.net|lid)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null) {
        directJid = match.group(0);
        break;
      }
    }

    final targetContact = (phoneDigits != null && phoneDigits.length >= 7)
        ? phoneDigits
        : directJid;

    // 2. Si disponemos de teléfono o JID, abre el chat con auto-envío o manual.
    if (targetContact != null && targetContact.isNotEmpty) {
      final contact = targetContact;
      final expected = widget.item.displayName.isNotEmpty
          ? widget.item.displayName
          : null;
      if (hasA11y) {
        if (mounted) {
          setState(
            () => _statusText = '⚡ Despachando con retorno automático...',
          );
        }
        final ok = await share.openChat(
          contact: contact,
          text: text,
          packageName: widget.item.packageName,
          autoSend: true,
          expectedAlias: expected,
        );
        if (mounted) {
          setState(() {
            _statusText = ok
                ? 'Mensaje despachado con retorno automático a Nano'
                : 'No se pudo abrir el chat de WhatsApp';
          });
        }
        return ok;
      } else {
        if (mounted) {
          setState(() {
            _busy = false;
            _statusText = 'Acción requerida para enviar sin salir de Nano';
          });
        }
        if (!mounted) return false;
        final action = await _showNoA11yOptionsModal(context, share);
        if (!mounted) return false;
        if (action == 'open_whatsapp') {
          final opened = await share.openChat(
            contact: contact,
            text: text,
            packageName: widget.item.packageName,
            autoSend: false,
            expectedAlias: expected,
          );
          if (mounted) {
            setState(() {
              _statusText = opened
                  ? 'Borrador abierto en WhatsApp; confirma allí el envío'
                  : 'No se pudo abrir WhatsApp';
            });
          }
        }
        return false;
      }
    }

    // 3. H3: Si no hay número ni JID resoluble, no se puede preparar borrador en WhatsApp.
    if (mounted) {
      setState(() {
        _statusText = 'No se encontró un número o identificador de WhatsApp válido para este contacto. '
            'Selecciona un contacto con teléfono o abre el chat manualmente.';
      });
    }
    return false;
  }
}
