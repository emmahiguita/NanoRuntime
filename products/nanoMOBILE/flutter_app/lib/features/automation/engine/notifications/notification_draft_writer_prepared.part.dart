part of 'notification_draft_writer.dart';

/// QUÉ: resultado inmutable de preparar un turno, separado del coordinador.
/// CÓMO: conserva sistema, mensaje e historial como campos independientes.
/// POR QUÉ: el estilo variable no debe invalidar el prefijo estable del KV local.
final class _PreparedDraftPrompt {
  const _PreparedDraftPrompt({
    required this.messageText,
    required this.prompt,
    required this.sessionId,
    required this.isSocial,
    required this.persona,
    required this.systemContext,
    required this.maxTokens,
    required this.history,
    required this.stopwatch,
  });

  final String messageText;
  final String prompt;
  final String sessionId;
  final bool isSocial;
  final String persona;
  final String systemContext;
  final int maxTokens;
  final List<Map<String, String>>? history;
  final Stopwatch stopwatch;

  /// La nube necesita autores e historial; este transporte no cambia el KV local.
  String get cloudPrompt => CloudTurnContext.compose(
    prompt: prompt,
    system: systemContext,
    history: history,
  );
}
