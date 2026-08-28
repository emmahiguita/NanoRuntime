/// A15.2 — Vocabulario FINITO de pasos semánticos para la descomposición LLM.
///
/// El modelo puede emitir SOLO estos `semanticAction`. NUNCA tool names
/// arbitrarios, shell, packages, selectores, coordenadas, intents o privilegios.
/// Candidate-First decide CÓMO se ejecuta cada paso; el LLM solo dice QUÉ hacer.
library;

/// Conjunto finito de semántica permitida (sección A15.2).
const kAllowedTaskSemantics = <String>{
  'readNotification',
  'extractUrl',
  'openApp',
  'openUrl',
  'observeScreen',
  'openConversation',
  'writeMessage',
  'sendMessage',
  'writeFile',
  'replyMessage',
  // T2.9 — búsqueda genérica dentro de una app.
  'writeQuery',
  'submitSearch',
};

/// Valida que una descomposición LLM solo use semántica permitida.
/// Devuelve el primer motivo de rechazo o null si es válida.
String? validateSemantics(List<String> semantics) {
  for (final s in semantics) {
    if (!kAllowedTaskSemantics.contains(s)) {
      return 'semántica no permitida: $s';
    }
  }
  return null;
}

/// Parámetros que consume/produce cada semántica (para bindings tipados).
/// Evita que el LLM invente variables o tipos.
const Map<String, List<String>> kSemanticInputs = {
  'readNotification': const [],
  'extractUrl': const ['text'],
  'openApp': const ['package'],
  'openUrl': const ['url'],
  'observeScreen': const [],
  'writeFile': const ['content'],
  'replyMessage': const ['key', 'text'],
  'writeQuery': const ['query'],
  'submitSearch': const [],
};
