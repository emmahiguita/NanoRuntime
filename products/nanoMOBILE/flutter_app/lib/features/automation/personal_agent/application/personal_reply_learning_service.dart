/// Aprendizaje idempotente de respuestas escritas y enviadas por el dueño.
///
/// Une una misma entrada normalizada en un solo ejemplo con varias respuestas.
/// Así un saludo, una pregunta o un enlace repetido no crea filas paralelas.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;

import '../domain/persona_example.dart';
import '../domain/personal_memory.dart';
import 'conversation_decision_guards.dart';
import 'persona_repository.dart';
import 'personal_learning_text.dart';
import 'personal_reply_correction_memory.dart';
import 'personal_reply_variants.dart';
import '../../engine/language/conversation_semantic_tag.dart';

part 'personal_reply_learning_metadata.dart';
part 'personal_reply_learning_consolidation.dart';
part 'personal_reply_learning_flow.dart';

enum PersonalReplyLearningResult { created, merged, unchanged, rejected }

final class PersonalReplyLearningService {
  PersonalReplyLearningService({PersonaRepository? repository})
    : _repository = repository ?? PersonaRepository.instance;

  static final instance = PersonalReplyLearningService();
  static const _observationScope = 'learning_observation';
  static const _observationTtlMs = 14 * 24 * 60 * 60 * 1000; // 14 días
  static const _automaticSources = {
    'whatsapp_manual_learned',
    'messaging_center_learning',
    'correction',
    'owner_import',
  };

  final PersonaRepository _repository;

  /// Guarda sólo evidencia humana real verificada; separa Observation != ConsolidatedMemory.
  Future<PersonalReplyLearningResult> learnVerifiedReply({
    required String incomingText,
    required String replyText,
    required String source,
    String? correctedFrom,
  }) async {
    final provenance = ReplyProvenance.fromSource(
      source,
      correctedFrom: correctedFrom,
    );
    if (!provenance.canTeachPersonalStyle) {
      return PersonalReplyLearningResult.rejected;
    }

    final incoming = incomingText.trim();
    final reply = replyText.trim();
    if (!isLearnablePersonalPrompt(incoming) ||
        reply.isEmpty ||
        reply.length > 280) {
      return PersonalReplyLearningResult.rejected;
    }

    final key = promptKey(incoming);
    final normalizedReply = replyKey(reply);
    if (key.isEmpty || normalizedReply.isEmpty) {
      return PersonalReplyLearningResult.rejected;
    }
    if (key == normalizedReply && key.split(' ').length > 2) {
      return PersonalReplyLearningResult.rejected;
    }

    final all = await _allExamples('owner');
    final matches = all
        .where(
          (example) =>
              promptKey(example.incomingText) == key ||
              example.incomingVariants.any(
                (variant) => promptKey(variant) == key,
              ),
        )
        .toList();

    if (matches.isEmpty) {
      var frequencyIncrement = 1;
      // Ciclo 11: Una observación pasiva única (Observation) no entra directo a
      // Persona permanente (ConsolidatedMemory); se persiste con TTL de 14 días.
      if (provenance == ReplyProvenance.humanPassiveObservation) {
        final count = await _recordPersistentObservation(
          patternFingerprint: key,
          responseFingerprint: normalizedReply,
          incoming: incoming,
          reply: reply,
          source: source,
        );
        if (count < 2) {
          return PersonalReplyLearningResult.unchanged;
        }
        frequencyIncrement = count;
      }

      final created = await _repository.addExample(
        personaKey: 'owner',
        incomingText: incoming,
        body: reply,
        source: source,
        tone: _learningToneFor(
          base: const {},
          incoming: incoming,
          incomingVariants: [incoming],
          replies: [reply],
          provenance: provenance,
          correctedFrom: correctedFrom,
          frequencyIncrement: frequencyIncrement,
        ),
      );
      if (created && correctedFrom != null) {
        await PersonalReplyCorrectionMemory(_repository).remember(
          incoming: incoming,
          reply: reply,
          correctedFrom: correctedFrom,
        );
      }
      if (created && provenance == ReplyProvenance.humanPassiveObservation) {
        await _clearPersistentObservation(key);
      }
      return created
          ? PersonalReplyLearningResult.created
          : PersonalReplyLearningResult.rejected;
    }

    final changed = await _mergeMatches(
      matches,
      incoming: incoming,
      newestReply: reply,
      provenance: provenance,
      correctedFrom: correctedFrom,
    );
    if (provenance == ReplyProvenance.humanPassiveObservation) {
      await _clearPersistentObservation(key);
    }
    if (correctedFrom != null) {
      await PersonalReplyCorrectionMemory(_repository).remember(
        incoming: incoming,
        reply: reply,
        correctedFrom: correctedFrom,
      );
    }
    return changed
        ? PersonalReplyLearningResult.merged
        : PersonalReplyLearningResult.unchanged;
  }

  static String promptKey(String raw) => normalizePersonalLearningText(raw);
  static String replyKey(String raw) => promptKey(raw);
}
