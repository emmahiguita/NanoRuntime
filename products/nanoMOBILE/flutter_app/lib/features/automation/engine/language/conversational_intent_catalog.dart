// conversational_intent_catalog.dart
//
// QUÉ HACE:
// Catálogo centralizado y canónico de intenciones del Agente Conversacional Personal.
//
// CÓMO FUNCIONA:
// Define identificadores estandarizados (IntentId) asociados a sus categorías macro,
// banderas de contexto requerido y protecciones de estado vivo (Live State).
//
// POR QUÉ:
// Elimina strings mágicos dispersos, desacopla la macro-categoría de la intención
// específica y cumple con los principios SOLID (SRP, OCP) en < 150 líneas.

library;

import 'hybrid_intent_classifier.dart' show HybridIntentCategory;

enum ConversationalIntentId {
  greeting('greeting', 'Saludo', HybridIntentCategory.socialEveryday),
  farewell('farewell', 'Despedida', HybridIntentCategory.socialEveryday),
  gratitude('gratitude', 'Agradecimiento', HybridIntentCategory.socialEveryday),
  wellbeingQuestion('wellbeing_question', 'Pregunta de bienestar', HybridIntentCategory.socialEveryday),
  wellbeingAnswer('wellbeing_answer', 'Respuesta de bienestar', HybridIntentCategory.socialEveryday),
  activityQuestion('activity_question', 'Pregunta de actividad', HybridIntentCategory.socialEveryday),
  availabilityQuestion('availability_question', 'Pregunta de disponibilidad', HybridIntentCategory.personalAppointmentOrPlan),
  locationQuestion('location_question', 'Pregunta de ubicación', HybridIntentCategory.socialEveryday),
  invitation('invitation', 'Invitación o propuesta de plan', HybridIntentCategory.personalAppointmentOrPlan),
  invitationAcceptance('invitation_acceptance', 'Aceptación de plan', HybridIntentCategory.personalAppointmentOrPlan),
  invitationRejection('invitation_rejection', 'Rechazo de plan', HybridIntentCategory.personalAppointmentOrPlan),
  meetingTimeQuestion('meeting_time_question', 'Pregunta por hora de encuentro', HybridIntentCategory.personalAppointmentOrPlan),
  meetingTimeAnswer('meeting_time_answer', 'Respuesta con hora o momento', HybridIntentCategory.personalAppointmentOrPlan),
  projectStatusQuestion('project_status_question', 'Pregunta sobre estado de proyecto', HybridIntentCategory.personalProjectOrFact),
  confirmation('confirmation', 'Confirmación o asentimiento', HybridIntentCategory.socialEveryday),
  negation('negation', 'Negación explícita', HybridIntentCategory.socialEveryday),
  correction('correction', 'Corrección dialógica', HybridIntentCategory.correctionOrContradiction),
  contextReference('context_reference', 'Referencia anafórica o contextual', HybridIntentCategory.contextualCoreference),
  externalInformationQuestion('external_information_question', 'Pregunta de actualidad externa', HybridIntentCategory.externalCurrentKnowledge),
  unknown('unknown', 'Intención no identificada', HybridIntentCategory.openComplexDialogue);

  final String id;
  final String label;
  final HybridIntentCategory macroCategory;

  const ConversationalIntentId(this.id, this.label, this.macroCategory);

  static ConversationalIntentId fromId(String? id) {
    if (id == null || id.trim().isEmpty) return ConversationalIntentId.unknown;
    final clean = id.trim().toLowerCase();
    for (final intent in values) {
      if (intent.id == clean) return intent;
    }
    return ConversationalIntentId.unknown;
  }

  bool get requiresLiveState =>
      this == ConversationalIntentId.locationQuestion ||
      this == ConversationalIntentId.activityQuestion;

  bool get requiresContext =>
      this == ConversationalIntentId.contextReference ||
      this == ConversationalIntentId.correction ||
      this == ConversationalIntentId.confirmation ||
      this == ConversationalIntentId.negation ||
      this == ConversationalIntentId.meetingTimeAnswer;
}
