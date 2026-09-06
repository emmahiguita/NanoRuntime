/// CAP-BROKER-01 — ReplyIntentVocabulary: ÚNICO vocabulario de clasificación
/// de intención de respuesta ("¿este goal pide responder un mensaje?").
///
/// Antes (WA-UI-07) el vocabulario vivía solo en el coordinator como
/// `_replyGoalTerms` y duplicado en varios parsers. Este archivo es la
/// fuente única para la CLASIFICACIÓN. Los parsers estructurales (extraer
/// target y mensaje) siguen siendo de `message_intent_parser` y migran a
/// este vocabulario en CAP-BROKER-02 (cambio mínimo por sprint).
library;

/// Clasificador puro de intención de respuesta. Misma lista de términos
/// que usaba el coordinator (comportamiento idéntico, cero regresión),
/// pero tipado y compartido: sin estado, sin plataforma, testeable.
abstract final class ReplyIntentVocabulary {
  /// Términos que expresan intención de RESPONDER un mensaje. El orden
  /// importa para `matches` ("responde a" gana sobre "responde").
  ///
  /// WA-REG-01 — formas naturales ancladas a contacto (escríbele/dile/
  /// mándale/envíale...). Sin verbos sueltos ("escribe", "envía"): un goal
  /// como "escribe un resumen" no debe clasificar como reply. El fast-path
  /// del coordinator además exige una notificación contestable, así que
  /// estos términos solo activan el camino determinista con destinatario
  /// real.
  static const List<String> terms = [
    'responde a',
    'contesta a',
    'escríbele a',
    'escríbele',
    'escribe a',
    'dile a',
    'mándale a',
    'mándale',
    'manda un whatsapp',
    'envíale a',
    'envíale',
    'envía a',
    'mensaje a',
    'whatsapp a',
    'responde',
    'responder',
    'contesta',
    'contestar',
    'reply',
  ];

  /// ¿El goal pide responder un mensaje? Comparación case-insensitive
  /// contra el vocabulario. Puro: sin estado, sin plataforma.
  static bool matches(String goal) {
    final g = goal.toLowerCase();
    return terms.any(g.contains);
  }
}
