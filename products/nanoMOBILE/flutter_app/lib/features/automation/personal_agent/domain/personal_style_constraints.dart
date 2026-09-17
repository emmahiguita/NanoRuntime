/// PERSONAL STYLE CONSTRAINTS
///
/// Restricciones duras de forma, longitud y vocabulario del dueño.
/// Gobierna tanto la composición determinista como la inyección en el prompt LLM.
library;

final class PersonalStyleConstraints {
  final int maxTypicalSentences;
  final String preferredAnswerLength;
  final bool preferredReciprocity;
  final List<String> preferredExpressions;
  final List<String> avoidExpressions;

  const PersonalStyleConstraints({
    this.maxTypicalSentences = 2,
    this.preferredAnswerLength = 'short',
    this.preferredReciprocity = true,
    this.preferredExpressions = const [
      'sí',
      'creo que sí',
      'gracias a Dios',
      '¿y tú?',
      'dale',
      'listo',
      'de una',
      'hagámosle',
      'puede ser',
      'aún no sé',
      'con gusto',
      'todo bien',
      'aquí haciendo unas cosas',
      'aquí en la casa',
    ],
    this.avoidExpressions = const [
      'por supuesto',
      'ciertamente',
      'será un placer',
      'entiendo perfectamente',
      '¿en qué más puedo ayudarte?',
      'me complace',
      'excelente pregunta',
      'no dudes en contactarme',
      'a tu entera disposición',
      'espero que te encuentres bien',
    ],
  });

  static const defaultEmmanuel = PersonalStyleConstraints();

  /// Líneas concisas para inyectar en el bloque de contexto del prompt
  String toPromptInstruction() {
    final avoidJoined = avoidExpressions.take(6).map((e) => '"$e"').join(', ');
    final prefJoined = preferredExpressions.take(8).map((e) => '"$e"').join(', ');
    return 'Restricciones de estilo del dueño:\n'
        '- Máximo $maxTypicalSentences frases cortas y directas, sin rodeos.\n'
        '- Respuestas cortas ($preferredAnswerLength) y naturales.\n'
        '- Devolver la pregunta cuando sea natural ("¿y tú?").\n'
        '- Expresiones preferidas: $prefJoined.\n'
        '- Prohibido terminantemente usar frases de asistente corporativo: $avoidJoined.';
  }
}
