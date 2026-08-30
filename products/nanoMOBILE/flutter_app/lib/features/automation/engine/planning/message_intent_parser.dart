/// T2.0 — MessageIntentParser: separa una intención de mensaje en lenguaje
/// natural en `recipient` + `message` de forma DETERMINISTA (0 LLM).
///
/// Necesario para "responde a Juan que llego a las 8": el target para el
/// matching de la conversación es "Juan", y el texto a enviar es "llego a las
/// 8". El parser NUNCA inventa un remitente ni un texto: si no hay verbo o no
/// hay separador de mensaje, devuelve los campos vacíos y el llamador decide
/// (reply sin texto = no reply, abrir la conversación).
///
/// Puro Dart: sin Flutter, sin IO, sin LLM. Reusable por el Notification-
/// CandidateProvider (reply por RemoteInput) y, en T2.8, por la mensajería
/// genérica por UI.
library;

/// Intención de mensaje parseada. Campos vacíos = no expresado en el objetivo
/// (honesto; no se rellena con texto inventado).
class MessageIntent {
  /// App objetivo ("WhatsApp"), de "abre X"/"ve a X". '' = no expresada.
  final String app;

  /// Destinatario ("Juan").
  final String recipient;

  /// Texto a enviar (payload del mensaje, proveniente de la orden del usuario).
  final String message;

  const MessageIntent({this.app = '', this.recipient = '', this.message = ''});

  bool get hasRecipient => recipient.isNotEmpty;
  bool get hasMessage => message.isNotEmpty;
}

/// Separa "responde a X que M" / "contesta a X: M" / "reply to X ...".
///
/// Regla determinista:
/// 1. localiza el verbo de respuesta (lista finita, coincidencia de prefijo más
///    específica primero);
/// 2. el resto se parte por el PRIMER separador de mensaje (` que ` o `:`);
/// 3. lo anterior es el recipient (se limpia de relleno "el último mensaje de");
/// 4. lo posterior es el message (se limpia de puntuación de borde).
class MessageIntentParser {
  const MessageIntentParser();

  /// Verbos de respuesta/mensajería, de más específico a menos (el orden
  /// importa: "responde a" gana sobre "responde"; "escríbele a" gana sobre
  /// "escríbele"; "envía un mensaje a" gana sobre "mensaje a").
  static const _verbs = [
    // Respuesta (ruta de notificación RemoteInput).
    'responde a',
    'responder a',
    'contesta a',
    'contestar a',
    'responde',
    'responder',
    'contesta',
    'contestar',
    'reply to',
    'reply',
    // Mensajería (ruta UI: abrir app → conversación → escribir → enviar).
    'escríbele a',
    'escribele a',
    'escríbale a',
    'escribe a',
    'manda un mensaje a',
    'envía un mensaje a',
    // W9: "envíale a X" (recipient tras verbo) y "envíale" (bare; recipient
    // desde "busca a Y").
    'envíale a',
    'enviale a',
    'envíale',
    'enviale',
    'mensaje a',
    'escríbele',
    'escribele',
    'escríbale',
    'escribe',
    'message to',
  ];

  /// Separadores que introducen el texto del mensaje. ` que `/` that ` primero
  /// porque son los patrones naturales más comunes; `:` cubre el formato
  /// "a X: mensaje".
  static const _messageDelimiters = [' que ', ' that ', ': ', ':'];

  /// Relleno que antecede al nombre real del remitente y debe descartarse.
  static const _recipientFillerPrefixes = [
    'el último mensaje de ',
    'el ultimo mensaje de ',
    'el último de ',
    'el ultimo de ',
    'el mensaje de ',
    'el mensaje a ',
    'a ',
  ];

  MessageIntent parse(String goal) {
    final g = goal.trim();
    if (g.isEmpty) return const MessageIntent();

    final lower = g.toLowerCase();
    final app = _extractApp(lower);

    String? verb;
    for (final v in _verbs) {
      if (lower.contains(v)) {
        verb = v;
        break;
      }
    }
    if (verb == null) {
      return MessageIntent(app: app, recipient: _extractConversationTarget(g));
    }

    // Recorta el verbo conservando el case original del resto (el mensaje no
    // se normaliza a minúsculas: es el payload real que se enviará).
    final verbIdx = lower.indexOf(verb);
    final rest = g.substring(verbIdx + verb.length).trim();
    if (rest.isEmpty) return MessageIntent(app: app);

    final split = _split(rest);
    var recipient = split.recipient;
    // W9: "envíale" sin "a" → el recipient viene de "busca a Y" (compuesto).
    if (recipient.isEmpty && (verb == 'envíale' || verb == 'enviale')) {
      recipient = _recipientFromSearch(g);
    }

    return MessageIntent(
      app: app,
      recipient: recipient,
      message: split.message,
    );
  }

  /// App objetivo desde "abre X" / "ve a X" / "ir a X" / "entra a|en X".
  String _extractApp(String lower) {
    final m = RegExp(
      r'(?:abre|abrir|ve a|ir a|entra a|entra en)\s+(\w+)',
    ).firstMatch(lower);
    return m?.group(1) ?? '';
  }

  /// Destino de una navegación conversacional sin escritura:
  /// "abre WhatsApp y entra en el grupo Seguimiento" → "Seguimiento".
  /// Mantiene el case original porque esta identidad se verificará contra la
  /// cabecera observada antes de considerar completada la navegación.
  String _extractConversationTarget(String goal) {
    final match = RegExp(
      r'(?:entra|entrar|abre|abrir|ve|ir|open|enter)\s+'
      r'(?:(?:a|en|into)\s+)?(?:(?:el|la|the)\s+)?'
      r'(?:grupo|group|chat|conversaci[oó]n|conversation)\s+'
      r'(?:de\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(goal);
    return _stripTrailingPunct(match?.group(1)?.trim() ?? '');
  }

  /// Recipient desde "busca a Y" / "búscale a Y" (compuesto W9). Conserva el
  /// case original del nombre.
  String _recipientFromSearch(String g) {
    final m = RegExp(
      r'(?:busca a|búscale a|buscale a)\s+([\wáéíóúñÁÉÍÓÚÑ]+)',
      caseSensitive: false,
    ).firstMatch(g);
    return m?.group(1) ?? '';
  }

  MessageIntent _split(String rest) {
    // Primer separador de mensaje (el más a la izquierda).
    var delim = '';
    var delimIdx = -1;
    for (final d in _messageDelimiters) {
      final i = rest.toLowerCase().indexOf(d);
      if (i >= 0 && (delimIdx < 0 || i < delimIdx)) {
        delim = d;
        delimIdx = i;
      }
    }

    var recipient = '';
    var message = '';
    if (delimIdx >= 0) {
      recipient = rest.substring(0, delimIdx).trim();
      message = rest.substring(delimIdx + delim.length).trim();
    } else {
      // Sin separador: todo es el recipient (el llamador verá que no hay texto).
      recipient = rest;
    }

    recipient = _stripTrailingPunct(recipient);
    message = _stripTrailingPunct(message);

    // "el último mensaje de Juan" → "Juan".
    final lowerRecipient = recipient.toLowerCase();
    for (final p in _recipientFillerPrefixes) {
      if (lowerRecipient.startsWith(p)) {
        recipient = recipient.substring(p.length).trim();
        break;
      }
    }

    return MessageIntent(recipient: recipient, message: message);
  }

  String _stripTrailingPunct(String s) =>
      s.replaceAll(RegExp(r'[?!.,;]+$'), '').trim();
}
