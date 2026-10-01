// QUÉ HACE: conserva respuestas externas como candidatas editables, no como hechos confiables.
// CÓMO: clasifica la pregunta con el catálogo existente y persiste un par normalizado y único.
// POR QUÉ: permite revisión humana sin enseñar respuestas externas no verificadas al agente.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../engine/language/conversational_intent_catalog.dart';
import '../../engine/language/conversational_intent_classifier.dart';
import 'personal_learning_text.dart';
import 'persona_repository.dart';

/// Registra solo la ruta cloud del agente personal; la generación local no entra aquí.
final class ExternalResponseExperienceLearningService {
  ExternalResponseExperienceLearningService({PersonaRepository? repository})
    : _repository = repository ?? PersonaRepository.instance;

  static final instance = ExternalResponseExperienceLearningService();
  final PersonaRepository _repository;

  /// QUÉ: guarda una respuesta de nube pendiente de revisión.
  /// CÓMO: SHA-256 de pregunta/respuesta normalizadas impide duplicados entre proveedores.
  /// POR QUÉ: conservar proveedor y categoría permite editarla sin confiarla automáticamente.
  Future<void> observe({
    required String input,
    required String response,
    required String provider,
  }) async {
    final question = input.trim();
    final answer = response.trim();
    final questionKey = normalizePersonalLearningText(question);
    final answerKey = normalizePersonalLearningText(answer);
    if (questionKey.isEmpty || answerKey.isEmpty || provider.trim().isEmpty) {
      return;
    }

    final prediction = const ConversationalIntentClassifier().classify(
      question,
    );
    final intent = ConversationalIntentId.fromId(
      prediction.primaryIntent.intentId,
    );
    final fingerprint = sha256
        .convert(utf8.encode('$questionKey\u0000$answerKey'))
        .toString();

    await _repository.addExample(
      personaKey: 'owner',
      incomingText: question,
      body: answer,
      source: 'ai_candidate:$fingerprint',
      tone: {
        'kind': 'external_candidate',
        'ownerVerified': 'false',
        'reusable': 'true',
        'provider': provider.trim(),
        'intent': intent.id,
        'category': intent.label,
        'title': question,
        'observedAt': DateTime.now().toIso8601String(),
      },
    );
  }
}
