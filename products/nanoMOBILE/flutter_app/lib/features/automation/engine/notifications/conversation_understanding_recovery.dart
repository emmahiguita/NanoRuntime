// conversation_understanding_recovery.dart
//
// QUÉ HACE:
// Rutinas de rescate y desescape para payloads JSON truncados o malformados devueltos
// por modelos de lenguaje en dispositivos móviles locales (0.5B / 1.5B).
//
// CÓMO FUNCIONA:
// 1. Localiza comillas no escapadas para cerrar strings truncados a la mitad.
// 2. Desescapa secuencias JSON estándar de forma segura sin lanzar excepciones.
// 3. Ofrece compatibilidad con protocolos textuales legacy ("Respuesta: ...").
//
// POR QUÉ:
// En dispositivos móviles con memoria acotada o límites estrictos de maxTokens, el JSON
// puede cortarse antes de la llave de cierre. Estas funciones salvan el `reply`
// sin descartar la inferencia ni bloquear la experiencia del usuario.

library;

import 'dart:convert';

/// Limpia el texto de respuesta quitando artefactos y etiquetas accidentales.
String cleanReplyText(String raw) {
  final trimmed = raw.trim();
  var candidate = trimmed;
  if (candidate.length > 2 &&
      candidate.startsWith('<') &&
      candidate.endsWith('>')) {
    final inner = candidate.substring(1, candidate.length - 1);
    if (!inner.contains('<') && !inner.contains('>')) {
      candidate = inner.trim();
    }
  }
  final stripped = candidate.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return stripped.isEmpty ? trimmed : stripped;
}

/// Recupera el valor de `"reply": "..."` cuando el JSON está incompleto.
String? recoverReplyFromJson(String trimmed) {
  final keyMatch = RegExp(
    r'"reply"\s*:\s*"',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (keyMatch == null) return null;
  var body = trimmed.substring(keyMatch.end);
  final close = findUnescapedQuote(body);
  if (close >= 0) {
    body = body.substring(0, close);
  } else {
    final cut = body.lastIndexOf('}');
    if (cut >= 0) body = body.substring(0, cut);
    body = body.trimRight();
    if (body.endsWith(',')) body = body.substring(0, body.length - 1);
    body = body.trimRight();
  }
  return cleanReplyText(unescapeJsonString(body.trim()));
}

/// Encuentra la primera comilla doble no precedida por barra invertida impar.
int findUnescapedQuote(String body) {
  var escaped = false;
  for (var i = 0; i < body.length; i++) {
    final c = body.codeUnitAt(i);
    if (escaped) {
      escaped = false;
      continue;
    }
    if (c == 0x5C) {
      escaped = true;
      continue;
    }
    if (c == 0x22) return i;
  }
  return -1;
}

/// Decodifica de forma tolerante secuencias de escape JSON.
String unescapeJsonString(String body) {
  if (!body.contains(r'\')) return body;
  try {
    return jsonDecode('"${body.replaceAll('"', r'\"')}"') as String;
  } on Object {
    return body
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n');
  }
}

/// Rescata respuestas con marcador textual antiguo ("Respuesta: ...").
String? legacyMarkerReply(String trimmed) {
  final m = RegExp(r'Respuesta\s*:', caseSensitive: false).firstMatch(trimmed);
  if (m == null) return null;
  final tail = trimmed.substring(m.end).trim();
  return tail.isEmpty ? null : cleanReplyText(tail);
}
