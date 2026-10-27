// QUÉ HACE: construye los metadatos persistidos de un aprendizaje personal.
// CÓMO: clasifica la intención y conserva variantes únicas dentro del límite SQLite.
// POR QUÉ: separa serialización del flujo transaccional de aprendizaje.

part of 'personal_reply_learning_service.dart';

/// Origen tipado de una respuesta observada (Ciclo 12: Self-Learning Loop).
///
/// Prelación de evidencia de estilo humano:
/// [humanManualReply] (4) > [nanoEditedByHuman] (3) > [humanPassiveObservation] (2) >
/// [nanoGeneratedReply] (0 - prohibido aprender) = [externalIncomingMessage] (0).
enum ReplyProvenance {
  humanManualReply(4, 'human_manual_reply', true),
  nanoEditedByHuman(3, 'nano_edited_by_human', true),
  humanPassiveObservation(2, 'human_passive_observation', true),
  nanoGeneratedReply(0, 'nano_generated_reply', false),
  externalIncomingMessage(0, 'external_incoming_message', false);

  final int priority;
  final String storageKey;
  final bool canTeachPersonalStyle;
  const ReplyProvenance(
    this.priority,
    this.storageKey,
    this.canTeachPersonalStyle,
  );

  static ReplyProvenance fromSource(String source, {String? correctedFrom}) {
    if (correctedFrom != null && correctedFrom.trim().isNotEmpty) {
      return ReplyProvenance.nanoEditedByHuman;
    }
    switch (source.trim()) {
      case 'manual':
      case 'manual_user':
      case 'messaging_center_learning':
        return ReplyProvenance.humanManualReply;
      case 'correction':
        return ReplyProvenance.nanoEditedByHuman;
      case 'whatsapp_manual_learned':
      case 'owner_import':
        return ReplyProvenance.humanPassiveObservation;
      case 'nano_generated':
      case 'fast_path':
      case 'llm_draft':
        return ReplyProvenance.nanoGeneratedReply;
      default:
        return ReplyProvenance.externalIncomingMessage;
    }
  }
}

Map<String, String> _learningToneFor({
  required Map<String, String> base,
  required String incoming,
  required List<String> incomingVariants,
  required List<String> replies,
  required ReplyProvenance provenance,
  String? correctedFrom,
  int frequencyIncrement = 1,
}) {
  final boundedReplies = fitLearningMetadata(replies.take(6).toList());
  final boundedIncoming = fitLearningMetadata(
    incomingVariants.take(6).toList(),
  );
  final semantic = ConversationSemanticClassifier.classify(incoming);
  final hasTimelessReply = boundedReplies.any(
    (text) => !ConversationDecisionGuards.affirmsOwnerActivity(text),
  );
  final previousFreq = int.tryParse(base['frequency'] ?? '') ?? 0;
  final nextFreq = (previousFreq + frequencyIncrement).clamp(1, 999);
  final baseConfidence = provenance == ReplyProvenance.humanManualReply
      ? 0.88
      : provenance == ReplyProvenance.nanoEditedByHuman
      ? 0.85
      : 0.65;
  final confidence = (baseConfidence + (nextFreq * 0.06)).clamp(0.60, 0.98);
  final canonicalKey = normalizePersonalLearningText(incoming);
  return {
    ...base,
    'ownerVerified': 'true',
    'provenance': provenance.storageKey,
    'provenancePriority': '${provenance.priority}',
    'kind': hasTimelessReply ? 'paired' : 'style',
    'reusable': hasTimelessReply ? 'true' : 'false',
    'memoryRole': hasTimelessReply
        ? 'reusable_dialogue'
        : 'style_and_historical_fact',
    'fingerprint': canonicalKey,
    'frequency': '$nextFreq',
    'confidence': confidence.toStringAsFixed(2),
    'intent': semantic.storageKey,
    'title': semantic.label,
    'category': semantic.label,
    'incomingVariants': jsonEncode(boundedIncoming),
    'variants': jsonEncode(boundedReplies),
    'responses': jsonEncode(
      boundedReplies
          .map((text) => PersonaResponseOption(text: text).toMap())
          .toList(),
    ),
    if (correctedFrom != null) 'correctedFrom': correctedFrom,
  };
}
