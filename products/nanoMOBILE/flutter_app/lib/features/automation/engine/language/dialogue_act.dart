// dialogue_act.dart
//
// QUÉ HACE:
// Define los actos conversacionales (DialogueAct) y el modelo de clasificación funcional
// de turnos (Pragmatic Dialogue Acts) para el motor conversacional de Nano Mobile.
//
// CÓMO FUNCIONA:
// Representa la función pragmática del mensaje dentro del flujo del diálogo
// (saludo, pregunta, reacción positiva, cierre, etc.), desacoplada del tema o intent semántico.
//
// POR QUÉ:
// Un intent como "wellbeing" no distingue entre preguntar "¿cómo estás?" y reaccionar
// "me alegra". El DialogueAct gobierna las reglas de respuesta, búsqueda y silencios.
// Cumple Clean Architecture y SOLID con archivos estrictamente < 200 líneas.

library;

/// Acto pragmático de comunicación que cumple un turno en la conversación.
enum DialogueAct {
  /// Saludo o apertura de contacto ("hola", "buenas").
  greeting,

  /// Pregunta sustantiva o solicitud de información ("¿qué haces?", "¿cuánto vale?").
  question,

  /// Respuesta informativa directa a una pregunta previa.
  answer,

  /// Reconocimiento o acuse de recibo neutro ("listo", "dale", "ok", "entendido").
  acknowledgement,

  /// Reacción empática o afectiva positiva ("me alegra", "qué bueno", "súper", "genial").
  positiveReaction,

  /// Reacción empática o afectiva negativa ("qué mal", "qué lástima", "grave").
  negativeReaction,

  /// Aclaración sobre un estado previamente expresado ("ya te dije que estoy bien").
  clarification,

  /// Corrección explícita de un malentendido ("no, me refería al móvil").
  correction,

  /// Continuación de reciprocidad o rebote ("¿y tú?", "¿y vos qué?").
  continuation,

  /// Despedida o cierre de la interacción ("chao", "hasta luego", "nos vemos").
  farewell,

  /// Petición de reparación o reintento ante incomprensión ("?", "¿cómo?", "¿qué dijiste?").
  repairRequest,

  /// Agradecimiento por un favor, respuesta o atención ("gracias", "mil gracias").
  gratitude,

  /// Mensaje misceláneo o declarativo abierto.
  statement;

  /// Indica si el acto es eminentemente reactivo/social sin necesidad de búsqueda fáctica.
  bool get isPurelySocial =>
      this == DialogueAct.greeting ||
      this == DialogueAct.acknowledgement ||
      this == DialogueAct.positiveReaction ||
      this == DialogueAct.negativeReaction ||
      this == DialogueAct.farewell ||
      this == DialogueAct.gratitude;

  /// Indica si el acto no requiere emitir una consulta o pregunta de retorno.
  bool get expectsNoQuestionReturn =>
      this == DialogueAct.acknowledgement ||
      this == DialogueAct.positiveReaction ||
      this == DialogueAct.negativeReaction ||
      this == DialogueAct.farewell ||
      this == DialogueAct.gratitude;
}

/// Resultado de la clasificación pragmática de actos de diálogo.
final class DialogueActClassification {
  final DialogueAct primaryAct;
  final Set<DialogueAct> secondaryActs;
  final double confidence;
  final String normalizedText;

  const DialogueActClassification({
    required this.primaryAct,
    this.secondaryActs = const {},
    required this.confidence,
    required this.normalizedText,
  });

  static const neutral = DialogueActClassification(
    primaryAct: DialogueAct.statement,
    confidence: 0.5,
    normalizedText: '',
  );
}
