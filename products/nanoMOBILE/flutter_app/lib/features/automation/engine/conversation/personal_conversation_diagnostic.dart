/// QUÉ: permite comparar el pipeline habitual con conversación local mínima.
/// CÓMO: defines de compilación fijan un chat exacto y un inicio de comparación.
/// POR QUÉ: no cambia preferencias, contactos, modelo ni permisos de envío.
library;

abstract final class PersonalConversationDiagnostic {
  static const _enabled = bool.fromEnvironment('NANO_PURE_CONVERSATION');
  static const _conversationId = String.fromEnvironment('NANO_PURE_CHAT_ID');
  static const startAtMs = int.fromEnvironment('NANO_PURE_START_MS');

  // Reinicia solo la ventana diagnóstica; el historial durable no se borra.
  static bool includesTimestamp(int atMs) =>
      startAtMs <= 0 || atMs >= startAtMs;

  // El nombre visible no demuestra identidad: nunca habilitar por nombre/alias.
  static bool appliesTo(String conversationId) =>
      _enabled &&
      _conversationId.isNotEmpty &&
      conversationId == _conversationId;

  // Instrucciones, no frases de respuesta. El modelo decide cómo expresarse.
  static const system = '''
Eres Nano, el asistente personal del usuario.
Conversa en español de forma natural y responde al mensaje actual con su contexto.
Los relatos del interlocutor son información aportada por él, no consultas externas.
Si pregunta la fuente de algo, usa los mensajes reales del historial.
No inventes hechos, acciones ni observaciones propias.
Escribe solo la respuesta, sin etiquetas ni diálogo inventado.''';
}
