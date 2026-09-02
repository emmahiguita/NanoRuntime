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
/// 4. lo posterior es el message y se conserva como payload literal.
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
    'envía a',
    'envia a',
    'manda a',
    'dile a',
    'decile a',
    'mándale a',
    'mandale a',
    'avísale a',
    'avisale a',
    'cuéntale a',
    'cuentale a',
    'text a',
    'write to',
    'envíale',
    'enviale',
    'mensaje a',
    'escríbele',
    'escribele',
    'escríbale',
    'dile',
    'decile',
    'mándale',
    'mandale',
    'avísale',
    'avisale',
    'cuéntale',
    'cuentale',
    'escribe',
    'text',
    'message to',
    'send to',
  ];

  /// Separadores que introducen el texto del mensaje. ` que `/` that ` primero
  /// porque son los patrones naturales más comunes; `:` cubre el formato
  /// "a X: mensaje". La coma se evalúa aparte ([_firstMessageComma]) para no
  /// partir identidades compuestas cuando tras ella viene el conector ` que `.
  static const _messageDelimiters = [' que ', ' that ', ': ', ':'];

  static final _trailingCommitDirective = RegExp(
    r'(?:\s*[,;]\s*|\s+(?:y|e|and|then)\s+)'
    r'(?:env[ií]alo|env[ií]ala|env[ií]a\s+el\s+mensaje|'
    r'm[aá]ndalo|m[aá]ndala|manda\s+el\s+mensaje|'
    r'pulsa\s+enviar|toca\s+enviar|send\s+it)\s*[.!?]*$',
    caseSensitive: false,
  );

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
    final conversationBeforeVerb = _extractConversationTarget(
      g.substring(0, verbIdx),
    );
    final rest = g.substring(verbIdx + verb.length).trim();
    if (rest.isEmpty) {
      return MessageIntent(app: app, recipient: conversationBeforeVerb);
    }

    // En una secuencia de navegación la conversación ya es el destinatario:
    // TODO lo que sigue al verbo pertenece al payload. Volver a partirlo por
    // `que` o `:` rompería mensajes legítimos como "tienes razón: hablamos".
    if (conversationBeforeVerb.isNotEmpty) {
      return MessageIntent(
        app: app,
        recipient: conversationBeforeVerb,
        message: _messagePayloadAfterBareVerb(rest),
      );
    }

    final split = _split(_stripCommitDirective(rest));
    var recipient = split.recipient;
    var message = split.message;

    // W9: "envíale" sin "a" → el recipient viene de "busca a Y" (compuesto).
    if (recipient.isEmpty && (verb == 'envíale' || verb == 'enviale')) {
      recipient = _recipientFromSearch(g);
    }

    return MessageIntent(
      app: app,
      recipient: recipient,
      message: _cleanMessagePayload(message),
    );
  }

  /// App objetivo desde "abre X" / "ve a X" / "ir a X" / "entra a|en X".
  String _extractApp(String lower) {
    final m = RegExp(
      r'(?:^|\b)(?:abre|abrir|ve\s+a|ir\s+a|entra\s+a|entra\s+en|open)\s+'
      r'(.+?)(?=\s*(?:[,;]|\s+(?:y|e|and|then)\s+)|$)',
    ).firstMatch(lower);
    final candidate = m?.group(1)?.trim() ?? '';
    // "abre el chat de Edgar" expresa una superficie, no una aplicación.
    // Dejar app vacía permite que el navegador trabaje en la app actual.
    if (RegExp(
      r'^(?:(?:el|la|the)\s+)?(?:chat|grupo|group|conversaci[oó]n|conversation)\b',
    ).hasMatch(candidate)) {
      return '';
    }
    return candidate;
  }

  /// Destino de una navegación conversacional sin escritura:
  /// "abre WhatsApp y entra en el grupo Seguimiento" → "Seguimiento".
  /// Mantiene el case original porque esta identidad se verificará contra la
  /// cabecera observada antes de considerar completada la navegación.
  String _extractConversationTarget(String goal) {
    final clause = goal
        .replaceFirst(
          RegExp(r'[\s,;]+(?:(?:y|e|and|then)\s*)?$', caseSensitive: false),
          '',
        )
        .trim();
    final match = RegExp(
      r'(?:entra|entrar|abre|abrir|ve|ir|open|enter)\s+'
      r'(?:(?:a|al|en|into)\s+)?(?:(?:el|la|the)\s+)?'
      r'(?:grupo|group|chat|conversaci[oó]n|conversation)\s+'
      r'(?:de\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(clause);
    return _stripTrailingPunct(match?.group(1)?.trim() ?? '');
  }

  /// Quita únicamente la puntuación/conector que separa el comando del
  /// payload. La puntuación final pertenece al mensaje del usuario y se
  /// conserva intacta.
  String _messagePayloadAfterBareVerb(String rest) => _cleanMessagePayload(
    rest.replaceFirst(
      RegExp(r'^\s*[,;:]?\s*(?:(?:que|that)\s+)?', caseSensitive: false),
      '',
    ),
  );

  /// Separa la instrucción de commit del contenido. Las comillas permiten que
  /// el usuario incluya puntuación y conectores sin que se interpreten como
  /// gramática. Un mensaje literal que termine en "y envíalo" debe ir entre
  /// comillas; fuera de ellas esa frase es una orden de envío.
  String _cleanMessagePayload(String value) {
    var payload = _stripCommitDirective(value);
    if (payload.length < 2) return payload;

    const quotePairs = {'"': '"', '“': '”', '‘': '’', "'": "'"};
    final closing = quotePairs[payload[0]];
    if (closing != null && payload.endsWith(closing)) {
      return payload.substring(1, payload.length - 1).trim();
    }
    return payload;
  }

  String _stripCommitDirective(String value) =>
      value.replaceFirst(_trailingCommitDirective, '').trim();

  /// Recipient desde "busca a Y" / "búscale a Y" (compuesto W9). Conserva el
  /// case original del nombre.
  String _recipientFromSearch(String g) {
    final m = RegExp(
      r'(?:busca a|búscale a|buscale a)\s+(.+?)'
      r'(?=\s+(?:y|e|and|then)\s+(?:env[ií]ale|env[ií]a|manda|send)\b|[,;:]|$)',
      caseSensitive: false,
    ).firstMatch(g);
    return _stripTrailingPunct(m?.group(1)?.trim() ?? '');
  }

  MessageIntent _split(String rest) {
    // "envía a Ana María \"llego a las 8\"". Si no hay `que` o `:`, las
    // comillas son el límite inequívoco entre identidad y payload.
    final quoted = RegExp(
      r'^(.+?)\s+(["“‘\x27])(.+)(["”’\x27])\s*$',
      caseSensitive: false,
    ).firstMatch(rest);
    if (quoted != null && _matchingQuotes(quoted.group(2)!, quoted.group(4)!)) {
      return MessageIntent(
        recipient: _stripTrailingPunct(quoted.group(1)!.trim()),
        message: quoted.group(3)!.trim(),
      );
    }

    // Primer separador de mensaje (el más a la izquierda). La coma compite
    // por la misma regla: "escríbele a emm, hola" separa identidad de payload
    // sin ambigüedad cuando no hay ` que `/`:` antes.
    var delim = '';
    var delimIdx = -1;
    for (final d in _messageDelimiters) {
      final i = rest.toLowerCase().indexOf(d);
      if (i >= 0 && (delimIdx < 0 || i < delimIdx)) {
        delim = d;
        delimIdx = i;
      }
    }
    final commaIdx = _firstMessageComma(rest);
    if (commaIdx != null && (delimIdx < 0 || commaIdx < delimIdx)) {
      delim = ',';
      delimIdx = commaIdx;
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
    message = message.trim();

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

  /// Índice de la coma que separa identidad de mensaje, o null. No se usa
  /// cuando tras la coma viene el conector ` que `/` that ` ("Ana, que llego
  /// tarde" deja la identidad intacta y el conector al payload) ni cuando la
  /// coma es puntuación final sin mensaje.
  int? _firstMessageComma(String rest) {
    final idx = rest.indexOf(',');
    if (idx < 0) return null;
    final after = rest.substring(idx + 1).trim();
    if (after.isEmpty) return null;
    if (RegExp(r'^(?:que|that)\b', caseSensitive: false).hasMatch(after)) {
      return null;
    }
    return idx;
  }

  bool _matchingQuotes(String opening, String closing) =>
      const {'"': '"', '“': '”', '‘': '’', "'": "'"}[opening] == closing;

  String _stripTrailingPunct(String s) =>
      s.replaceAll(RegExp(r'[?!.,;]+$'), '').trim();
}
