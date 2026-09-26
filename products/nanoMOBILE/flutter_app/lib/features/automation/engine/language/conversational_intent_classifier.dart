// conversational_intent_classifier.dart
//
// QUÉ HACE:
// Clasificador NLU local híbrido y determinista con segmentación de cláusulas para Nano Personal.
//
// CÓMO FUNCIONA:
// 1. Divide turnos compuestos en cláusulas. 2. Extrae intención, polaridad, correcciones,
// referencias y protecciones de estado vivo. 3. Agrega intenciones primarias/secundarias y evidencia.
//
// POR QUÉ:
// Resuelve preguntas compuestas ("hola, vas a entrenar?"), evita respuestas estériles a negaciones
// o correcciones y asegura latencias < 5ms en móvil sin dependencia de LLMs (< 180 líneas).

library;

import 'conversational_intent_catalog.dart';
import 'intent_prediction.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_learning_text.dart'
    show normalizePersonalLearningText;
import 'semantic_similarity_engine.dart';

final class ConversationalIntentClassifier {
  final SemanticSimilarityEngine similarityEngine;
  final double ambiguityMargin;

  const ConversationalIntentClassifier({
    this.similarityEngine = const LightweightSemanticSimilarityEngine(),
    this.ambiguityMargin = 0.06,
  });

  /// Clasifica un mensaje completo descomponiéndolo en cláusulas primarias y secundarias.
  AggregatedIntentPrediction classify(String rawText, {String? storedIntentHint}) {
    final clean = rawText.trim();
    if (clean.isEmpty) {
      return const AggregatedIntentPrediction(
        primaryIntent: IntentPrediction.unknown, overallConfidence: 0.0);
    }

    final clauses = _splitIntoClauses(clean);
    final list = [for (final c in clauses) ClauseIntentPrediction(clause: c, prediction: _classifyClause(c, storedIntentHint))];
    if (list.isEmpty) {
      final s = _classifyClause(clean, storedIntentHint);
      return AggregatedIntentPrediction(primaryIntent: s, clausePredictions: [ClauseIntentPrediction(clause: clean, prediction: s)], overallConfidence: s.confidence);
    }

    list.sort((a, b) {
      final rComp = _priorityRank(b.prediction.intentId).compareTo(_priorityRank(a.prediction.intentId));
      return rComp != 0 ? rComp : b.prediction.confidence.compareTo(a.prediction.confidence);
    });

    final primary = list.first.prediction;
    final secondaries = list.skip(1).map((cp) => cp.prediction).where((p) => p.intentId != primary.intentId).toList();

    var isAmbiguous = false;
    if (secondaries.isNotEmpty) {
      final diff = (primary.confidence - secondaries.first.confidence).abs();
      if (diff < ambiguityMargin && primary.intentId != secondaries.first.intentId) isAmbiguous = true;
    }

    final finalPrimary = IntentPrediction(
      macroIntent: primary.macroIntent, intentId: primary.intentId, confidence: primary.confidence,
      topics: primary.topics, entities: primary.entities, temporalAnchor: primary.temporalAnchor,
      polarity: primary.polarity, needsContext: primary.needsContext, needsClarification: isAmbiguous,
      requiresLiveState: primary.requiresLiveState, evidence: primary.evidence,
    );

    return AggregatedIntentPrediction(primaryIntent: finalPrimary, secondaryIntents: secondaries, clausePredictions: list, overallConfidence: finalPrimary.confidence);
  }

  IntentPrediction _classifyClause(String clause, String? hint) {
    final norm = normalizePersonalLearningText(clause);
    final polarity = IntentPolarity.fromText(clause);
    final evidence = <IntentEvidence>[];

    if (_isCorrection(norm)) {
      evidence.add(const IntentEvidence(source: 'pragmatic', score: 0.95, detail: 'correction_cue'));
      return IntentPrediction(macroIntent: ConversationalIntentId.correction.macroCategory.name, intentId: ConversationalIntentId.correction.id, confidence: 0.95, polarity: polarity, needsContext: true, evidence: evidence);
    }

    if (_isEllipticalOrContextual(norm, clause)) {
      evidence.add(const IntentEvidence(source: 'context', score: 0.88, detail: 'contextual_cue'));
      return IntentPrediction(macroIntent: ConversationalIntentId.contextReference.macroCategory.name, intentId: ConversationalIntentId.contextReference.id, confidence: 0.88, polarity: polarity, needsContext: true, evidence: evidence);
    }

    if (hint != null && hint.isNotEmpty && ConversationalIntentId.fromId(hint) != ConversationalIntentId.unknown) {
      evidence.add(IntentEvidence(source: 'storedVariant', score: 0.92, detail: 'stored_hint:$hint'));
    }

    final best = _matchIntentPatterns(norm, clause, evidence);
    final maxScore = evidence.isNotEmpty ? evidence.map((e) => e.score).reduce((a, b) => a > b ? a : b) : 0.60;
    return IntentPrediction(
      macroIntent: best.macroCategory.name, intentId: best.id, confidence: maxScore,
      polarity: polarity, needsContext: best.requiresContext, requiresLiveState: best.requiresLiveState, evidence: evidence,
    );
  }

  static ConversationalIntentId _matchIntentPatterns(String norm, String raw, List<IntentEvidence> evidence) {
    // 1. Preguntas de proyectos y tecnología (prioridad sobre bienestar para evitar falsos positivos con "proyecto?")
    if (norm.contains('proyecto') || norm.contains('codigo') || norm.contains('app') || norm.contains('sistema') || (norm.contains('avanzaste') && (norm.contains('codigo') || norm.contains('app')))) {
      evidence.add(const IntentEvidence(source: 'lexical', score: 0.92, detail: 'project_cue'));
      return ConversationalIntentId.projectStatusQuestion;
    }
    // 2. Ubicación y presencia viva
    if (norm.contains('donde estas') || norm.contains('donde andas') || norm.contains('en donde andas') || norm.contains('por donde andas') || (norm.contains('estas en casa') && !norm.contains('como esta'))) {
      evidence.add(const IntentEvidence(source: 'semantic', score: 0.94, detail: 'location_inquiry'));
      return ConversationalIntentId.locationQuestion;
    }
    // 3. Horarios y preguntas de citas
    if (norm.contains('a que hora') || norm.contains('que hora') || norm.contains('a que horas') || norm.contains('tipo que hora')) {
      evidence.add(const IntentEvidence(source: 'lexical', score: 0.93, detail: 'meeting_time_q'));
      return ConversationalIntentId.meetingTimeQuestion;
    }
    if (RegExp(r'\b(?:a\s+las|tipo)\s+(?:\d+|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|tarde|pm|am)\b').hasMatch(norm) || (norm.startsWith('tipo ') && RegExp(r'\d').hasMatch(norm))) {
      evidence.add(const IntentEvidence(source: 'lexical', score: 0.91, detail: 'meeting_time_ans'));
      return ConversationalIntentId.meetingTimeAnswer;
    }
    // 4. Bienestar
    if (norm.contains('como estas') || norm.contains('como vas') || norm.contains('que tal') || norm.contains('todo bien') || norm.contains('todo bn') || norm.contains('como te ha ido') || norm.contains('como andas') || norm.contains('como sigue') || norm.contains('como te trata') || (norm.contains('como esta') && (norm.contains('tu casa') || norm.contains('su casa')))) {
      evidence.add(const IntentEvidence(source: 'semantic', score: 0.93, detail: 'wellbeing_cue'));
      return ConversationalIntentId.wellbeingQuestion;
    }
    // 5. Actividad y disponibilidad
    if (norm.contains('que haces') || norm.contains('que estas haciendo') || norm.contains('que andas haciendo') || norm.contains('en que andas')) {
      evidence.add(const IntentEvidence(source: 'semantic', score: 0.90, detail: 'activity_cue'));
      return ConversationalIntentId.activityQuestion;
    }
    if (norm.contains('vas a') || norm.contains('estas libre') || norm.contains('tienes tiempo') || norm.contains('puedes hablar')) {
      evidence.add(const IntentEvidence(source: 'semantic', score: 0.88, detail: 'availability_cue'));
      return ConversationalIntentId.availabilityQuestion;
    }
    // 6. Agradecimiento y Despedida
    if (norm.contains('gracias') || norm.contains('agradec') || norm.contains('agradez') || norm == 'grx' || norm.contains('muy amable')) {
      evidence.add(const IntentEvidence(source: 'pragmatic', score: 0.96, detail: 'gratitude_ack'));
      return ConversationalIntentId.gratitude;
    }
    if (norm.contains('chao') || norm.contains('hasta luego') || norm.contains('nos vemos') || norm.contains('hablamos') || norm.contains('adios') || norm.contains('descans') || norm.contains('hasta manana') || norm.contains('chaito')) {
      evidence.add(const IntentEvidence(source: 'pragmatic', score: 0.95, detail: 'farewell_ack'));
      return ConversationalIntentId.farewell;
    }
    // 7. Saludos
    if (norm.startsWith('hola') || norm.startsWith('buenas') || norm.startsWith('buenos') || norm.startsWith('buen dia') || norm.startsWith('hey') || norm == 'oe' || norm == 'q mas' || norm.startsWith('quiubo')) {
      evidence.add(const IntentEvidence(source: 'pragmatic', score: 0.95, detail: 'greeting_ack'));
      return ConversationalIntentId.greeting;
    }
    // 8. Negaciones y Confirmaciones
    if (norm == 'no' || norm == 'nop' || norm.startsWith('no ') || norm.contains('no creo') || norm.contains('creo que no') || norm.contains('no puedo') || norm.contains('para nada') || norm.contains('tampoco') || norm.contains('no voy')) {
      evidence.add(const IntentEvidence(source: 'lexical', score: 0.92, detail: 'negation'));
      return ConversationalIntentId.negation;
    }
    if (norm == 'si' || norm == 'sip' || norm.startsWith('si ') || norm.contains('dale') || norm.contains('de una') || norm.contains('listo') || norm.contains('claro')) {
      evidence.add(const IntentEvidence(source: 'lexical', score: 0.92, detail: 'confirmation'));
      return ConversationalIntentId.confirmation;
    }
    evidence.add(const IntentEvidence(source: 'lexical', score: 0.50, detail: 'fallback'));
    return ConversationalIntentId.unknown;
  }

  static bool _isCorrection(String norm) =>
      norm.contains('no yo decia') || norm.contains('no era eso') || norm.contains('me referia a') || norm.contains('no te pregunte') || norm.contains('no me referia');

  static bool _isEllipticalOrContextual(String norm, String raw) =>
      norm.startsWith('y vos') || norm.startsWith('y tu') || norm.contains('lo de') || norm == 'vas' || norm == 'vas?' || norm.startsWith('y entonces') || norm.startsWith('y a que hora');

  static int _priorityRank(String intentId) {
    if (intentId == ConversationalIntentId.correction.id) return 100;
    if (intentId == ConversationalIntentId.projectStatusQuestion.id) return 95;
    if (intentId == ConversationalIntentId.locationQuestion.id || intentId == ConversationalIntentId.availabilityQuestion.id) return 90;
    if (intentId == ConversationalIntentId.meetingTimeQuestion.id || intentId == ConversationalIntentId.meetingTimeAnswer.id) return 88;
    if (intentId == ConversationalIntentId.activityQuestion.id) return 85;
    if (intentId == ConversationalIntentId.gratitude.id) return 75;
    if (intentId == ConversationalIntentId.wellbeingQuestion.id) return 70;
    if (intentId == ConversationalIntentId.farewell.id) return 65;
    if (intentId == ConversationalIntentId.confirmation.id || intentId == ConversationalIntentId.negation.id) return 60;
    if (intentId == ConversationalIntentId.greeting.id) return 50;
    return 40;
  }

  static List<String> _splitIntoClauses(String text) => text
      .split(RegExp(r'(?<=[.?!;\n])\s+|\s+(?:y\s+(?:si|vas|que)|pero\s+)\b|(?<=\b(?:hola|buenas|hey|quiubo))\s+(?=(?:que|qué|como|cómo|donde|dónde|a que|a qué))\b', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
