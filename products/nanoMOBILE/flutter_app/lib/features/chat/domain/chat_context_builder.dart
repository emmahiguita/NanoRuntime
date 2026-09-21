import '../../../core/models/chat_models.dart';
import '../../../core/services/chat_system_prompt.dart';

/// Constructor y saneador de contexto para el LLM móvil.
///
/// Responsabilidad única (SRP): ensamblar los turnos role/content y el prompt
/// para la inferencia, asegurando límites móviles y filtrado de fallos previos.
class ChatContextBuilder {
  static const int maxHistoryMessages = 10;
  static const int maxHistoryChars = 1200;
  static const int maxUserChars = 2000;
  static const int maxAttachmentChars = 1500;
  static const int maxToolTraceChars = 900;

  const ChatContextBuilder();

  /// Construye el historial como lista de turnos role/content para el motor.
  ///
  /// El core nanortime aplica el chat template REAL del GGUF y convierte
  /// estos turnos en bloques nativos del template.
  List<Map<String, String>> buildHistory(
    List<ChatMessage> history,
    List<String> toolTrace,
  ) {
    final result = <Map<String, String>>[];
    final window = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    for (final msg in window) {
      result.add({
        'role': msg.sender == MessageSender.user ? 'user' : 'assistant',
        'content': ChatSystemPrompt.promptClip(msg.text, maxHistoryChars),
      });
    }

    // Trace de herramientas: la llamada JSON como assistant y el resultado
    // real como user, para que el modelo continúe informado del resultado.
    for (var i = 0; i + 1 < toolTrace.length; i += 2) {
      result.add({
        'role': 'assistant',
        'content': ChatSystemPrompt.promptClip(
          toolTrace[i],
          maxToolTraceChars,
        ),
      });
      result.add({
        'role': 'user',
        'content':
            'Resultado de la herramienta:\n'
            '${ChatSystemPrompt.promptClip(toolTrace[i + 1], maxToolTraceChars)}',
      });
    }
    return result;
  }

  /// Devuelve el historial anterior al turno user actual. En rondas con tools,
  /// el estado ya contiene mensajes assistant con llamadas JSON visibles;
  /// esos mensajes pertenecen al turno en curso y se reinyectan vía toolTrace.
  /// Busca de atrás hacia adelante para capturar el turno actual.
  List<ChatMessage> historyBeforeCurrentUser(
    List<ChatMessage> messages,
    String text,
  ) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.sender == MessageSender.user && msg.text == text) {
        return sanitizeContext(messages.sublist(0, i));
      }
    }
    final lastUserIdx = messages.lastIndexWhere(
      (m) => m.sender == MessageSender.user,
    );
    if (lastUserIdx >= 0) {
      return sanitizeContext(messages.sublist(0, lastUserIdx));
    }
    return sanitizeContext(messages);
  }

  /// Quita mensajes AI fallidos del contexto. Evita que alimentar al modelo
  /// con el texto de su propio fallo lo confunda y degrade la generación.
  List<ChatMessage> sanitizeContext(List<ChatMessage> messages) {
    return messages
        .where(
          (m) =>
              !(m.sender == MessageSender.ai &&
                  m.status == MessageStatus.error),
        )
        .toList();
  }

  /// Construye el texto del prompt combinando adjuntos (si aplica) y texto de usuario.
  String buildPrompt({
    required String text,
    required List<ChatAttachment> attachments,
    required bool isFirstRound,
  }) {
    final attachmentText = isFirstRound
        ? ChatSystemPrompt.attachmentsBlock(attachments, maxAttachmentChars)
        : '';
    final clippedUser = ChatSystemPrompt.promptClip(text, maxUserChars);
    return '$attachmentText$clippedUser';
  }
}
