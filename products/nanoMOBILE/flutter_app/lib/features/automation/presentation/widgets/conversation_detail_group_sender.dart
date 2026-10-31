part of 'conversation_detail_sheet.dart';

/// [ConversationDetailGroupSender]
///
/// QUÉ HACE:
/// Gestiona la inyección y despacho de mensajes hacia grupos de WhatsApp confirmados
/// en el panel de mensajería cuando no hay RemoteInput en barra.
///
/// CÓMO FUNCIONA:
/// 1. Inyección directa: si WhatsApp está visible en pantalla (como ventana inferior o fondo),
///    escribe el texto en `com.whatsapp:id/entry` y pulsa `com.whatsapp:id/send` mediante
///    accesibilidad, sin exigir número ni bloquear con advertencias.
/// 2. Apertura directa por JID: si no está en pantalla pero existe JID oficial (`@g.us`),
///    despacha un Intent oficial a WhatsApp con retorno automático.
/// 3. Lanzamiento preparado: si no hay JID, abre WhatsApp con el borrador listo.
///
/// POR QUÉ:
/// Si una conversación aparece en el panel de mensajería, el destino ya está confirmado
/// por el historial previo de Nano. Los grupos no tienen número telefónico; rechazar el envío
/// o pedir un número bloquea injustificadamente al usuario.
extension ConversationDetailGroupSender on _ConversationDetailSheetState {
  /// Busca un JID oficial de grupo (`@g.us`) en la identidad o alias del elemento.
  String? _findGroupJid() {
    for (final raw in [
      widget.item.conversationId,
      ...widget.item.conversationAliases,
    ]) {
      final match = RegExp(
        r'[w.-]+@g.us',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null) return match.group(0);
    }
    return null;
  }

  /// H1: Valida que la conversación visible en WhatsApp coincida con el contacto o grupo seleccionado.
  bool _verifyConversationHeader(List<dynamic> nodes, String pkg) {
    final expectedNames = <String>{
      if (widget.item.displayName.isNotEmpty) widget.item.displayName.trim().toLowerCase(),
      if (widget.item.groupTitle != null && widget.item.groupTitle!.isNotEmpty)
        widget.item.groupTitle!.trim().toLowerCase(),
    };
    if (expectedNames.isEmpty) return false;

    final headerIds = {
      '/conversation_contact_name',
      '/conversation_contact',
      '/chat_title',
    };

    final headerNodes = nodes.where((n) {
      if (n.packageName != pkg || !n.visible) return false;
      return headerIds.contains(n.id);
    }).toList();

    for (final node in headerNodes) {
      final text = (node.text ?? '').trim().toLowerCase();
      final desc = (node.description ?? '').trim().toLowerCase();
      for (final expected in expectedNames) {
        if (text == expected || desc == expected) {
          return true;
        }
      }
    }
    return false;
  }

  /// Inyecta el texto directamente en el editor visible de WhatsApp SOLO si el chat coincide.
  Future<bool> _tryDirectInjection(String text) async {
    final executor = NanoAgentExecutor();
    final snap = await executor.snapshot();
    if (snap == null || snap.nodes.isEmpty) return false;

    // Busca los nodos de WhatsApp en cualquier ventana interactiva visible
    final whatsappNodes = snap.nodes
        .where(
          (n) =>
              n.packageName == 'com.whatsapp' ||
              n.packageName == 'com.whatsapp.w4b',
        )
        .toList();
    if (whatsappNodes.isEmpty) return false;

    final pkg = whatsappNodes.first.packageName;

    // H1: Valida encabezado de conversación visible antes de tocar el editor
    if (!_verifyConversationHeader(whatsappNodes, pkg)) {
      return false; // Fail-closed: el chat visible no es el seleccionado en Nano
    }

    // Campo de entrada de mensaje de WhatsApp
    final editors = whatsappNodes
        .where((n) => n.visible && n.editable && n.id == '/entry')
        .toList();
    if (editors.isEmpty) return false;

    if (mounted) {
      setState(() => _statusText = 'Inyectando mensaje en WhatsApp...');
    }

    // Escribe el texto en el editor de WhatsApp
    final writeResult = await executor.setText(
      NanoSelector(packageName: pkg, resourceId: '/entry'),
      text,
    );
    if (!writeResult.ok) return false;

    // Breve espera para que el icono de micrófono pase a botón de enviar
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Busca el botón de envío
    final snapAfter = await executor.snapshot();
    final candidateSendNodes = (snapAfter?.nodes ?? snap.nodes)
        .where(
          (n) =>
              n.packageName == pkg &&
              n.visible &&
              (n.id == '/send' ||
                  n.description.trim().toLowerCase() == 'enviar' ||
                  n.description.trim().toLowerCase() == 'send'),
        )
        .toList();

    if (candidateSendNodes.isNotEmpty) {
      final sendNode = candidateSendNodes.first;
      final tapResult = await executor.tap(
        NanoSelector(
          packageName: pkg,
          resourceId: sendNode.id.isNotEmpty ? sendNode.id : null,
          description:
              sendNode.description.isNotEmpty ? sendNode.description : null,
        ),
      );
      return tapResult.ok;
    }

    // H1: Si no se pulsó el botón enviar, no reportar éxito de envío
    return false;
  }

  /// Ejecuta la estrategia completa de envío para grupos cuando no hay RemoteInput disponible.
  Future<bool> _sendToGroupFallback({
    required String text,
    required WhatsAppMediaShare share,
    required bool hasA11y,
  }) async {
    // 1. Si la accesibilidad está habilitada, intenta inyectar directamente en WhatsApp.
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

    // 2. Si disponemos del JID oficial del grupo, abrimos directamente el chat.
    final groupJid = _findGroupJid();
    if (groupJid != null) {
      if (mounted) {
        setState(
          () => _statusText = hasA11y
              ? '⚡ Despachando al grupo con retorno automático...'
              : 'Abriendo grupo en WhatsApp...',
        );
      }
      final ok = await share.openChat(
        contact: groupJid,
        text: text,
        packageName: widget.item.packageName,
        autoSend: hasA11y,
        expectedAlias: widget.item.groupTitle ?? widget.item.displayName,
      );
      if (mounted) {
        setState(() {
          _statusText = ok
              ? (hasA11y
                  ? 'Mensaje despachado al grupo con retorno automático'
                  : 'Borrador abierto en WhatsApp; pulsa Enviar')
              : 'No se pudo abrir WhatsApp';
        });
      }
      return ok && hasA11y;
    }

    // 3. H3: Si no está en pantalla ni hay JID de grupo (@g.us), no inventar borrador sin destino.
    if (mounted) {
      setState(() {
        _statusText = 'No se encontró el identificador oficial (@g.us) de este grupo. '
            'Abre la conversación en WhatsApp para que Nano registre su identidad.';
      });
    }
    return false;
  }
}
