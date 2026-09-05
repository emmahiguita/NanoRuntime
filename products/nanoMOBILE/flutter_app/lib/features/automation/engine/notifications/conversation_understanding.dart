/// WA-CONV-01 — entendimiento estructurado de conversación (JSON).
///
/// Reemplaza el protocolo textual "Razonamiento:/Respuesta:" del borrador de
/// notificación: el modelo devuelve UN objeto JSON con claves ASCII estables
/// y el valor `reply` listo para enviar. El razonamiento NO se pide en texto
/// (tokens quemados + parseo frágil con el 0.5B); la comprensión viaja en
/// campos estructurados que WA-BUSINESS-01 consumirá para resolver hechos
/// antes de responder.
///
/// Parser TOLERANTE por diseño (modelos locales):
/// 1. Objeto JSON completo (primera `{` a última `}`) → campos tipados.
/// 2. JSON roto pero `"reply":"..."` recuperable → solo el reply (escapes
///    básicos \", \\, \n).
/// 3. Legacy: marcador "Respuesta:" (compatibilidad de arrastre mientras el
///    modelo viejo/otro flujo emita el formato antiguo).
/// 4. Nada → '' (sin borrador: honesto, nunca eco del JSON como respuesta).
library;

import 'dart:convert';

/// Entendimiento tipado del mensaje (v1: diagnóstico + reply; los campos
/// comerciales se consumen en WA-BUSINESS-01).
final class ConversationUnderstanding {
  final String intent;
  final List<String> questions;
  final List<String> missingFacts;
  final bool requiresAction;
  final String reply;

  const ConversationUnderstanding({
    this.intent = '',
    this.questions = const [],
    this.missingFacts = const [],
    this.requiresAction = false,
    this.reply = '',
  });

  bool get hasReply => reply.isNotEmpty;

  factory ConversationUnderstanding.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? raw) => [
      for (final v in raw is List ? raw : const <dynamic>[])
        if (v is String && v.isNotEmpty) v,
    ];
    return ConversationUnderstanding(
      intent: (json['intent'] as String?)?.trim() ?? '',
      questions: strings(json['questions']),
      missingFacts: strings(json['missingFacts']),
      requiresAction: json['requiresAction'] == true,
      reply: _cleanReply((json['reply'] as String?) ?? ''),
    );
  }

  static String _cleanReply(String raw) => raw.trim();
}

/// Parsea la salida cruda del modelo y devuelve el texto a enviar ('' si no
/// hay nada recuperable). Traza corta para diagnóstico físico (logcat).
String parseConversationReply(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  // 1) Objeto JSON completo.
  final jsonReply = _tryFullJson(trimmed);
  if (jsonReply != null) return jsonReply;

  // 2) reply recuperable de un JSON roto (recorte a mitad de objeto).
  final recovered = _recoverReply(trimmed);
  if (recovered != null) return recovered;

  // 3) Legacy: marcador textual del protocolo anterior.
  final legacy = _legacyMarkerReply(trimmed);
  if (legacy != null) return legacy;

  return '';
}

String? _tryFullJson(String trimmed) {
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(trimmed.substring(start, end + 1));
    if (decoded is Map) {
      final reply = ConversationUnderstanding.fromJson(
        decoded.cast<String, dynamic>(),
      ).reply;
      if (reply.isNotEmpty) return reply;
    }
  } on Object {
    // JSON inválido: cae al siguiente escalón.
  }
  return null;
}

/// Recupera el valor de `"reply": "..."` cuando el JSON está incompleto
/// (salida recortada por maxTokens): toma el texto entre la apertura de
/// comillas y el cierre no escapado; sin cierre, el resto hasta `}`.
String? _recoverReply(String trimmed) {
  final keyMatch = RegExp(
    r'"reply"\s*:\s*"',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (keyMatch == null) return null;
  var body = trimmed.substring(keyMatch.end);
  final close = _findUnescapedQuote(body);
  if (close >= 0) {
    body = body.substring(0, close);
  } else {
    // Recorte: quitar sobrantes estructurales y el cierre parcial.
    final cut = body.lastIndexOf('}');
    if (cut >= 0) body = body.substring(0, cut);
    body = body.trimRight();
    if (body.endsWith(',')) body = body.substring(0, body.length - 1);
    body = body.trimRight();
  }
  return _unescape(body.trim());
}

int _findUnescapedQuote(String body) {
  var escaped = false;
  for (var i = 0; i < body.length; i++) {
    final c = body.codeUnitAt(i);
    if (escaped) {
      escaped = false;
      continue;
    }
    if (c == 0x5C) { // backslash
      escaped = true;
      continue;
    }
    if (c == 0x22) return i; // comilla sin escapar
  }
  return -1;
}

String _unescape(String body) {
  if (!body.contains(r'\')) return body;
  try {
    // Re-encodear como JSON string valida los escapes reales del modelo.
    return jsonDecode('"${body.replaceAll('"', r'\"')}"') as String;
  } on Object {
    return body
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n');
  }
}

String? _legacyMarkerReply(String trimmed) {
  final m = RegExp(r'Respuesta\s*:', caseSensitive: false).firstMatch(trimmed);
  if (m == null) return null;
  final tail = trimmed.substring(m.end).trim();
  return tail.isEmpty ? null : tail;
}
