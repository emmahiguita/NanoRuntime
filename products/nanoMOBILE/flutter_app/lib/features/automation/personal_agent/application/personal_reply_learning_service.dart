/// Aprendizaje idempotente de respuestas escritas y enviadas por el dueño.
///
/// Une una misma entrada normalizada en un solo ejemplo con varias respuestas.
/// Así un saludo, una pregunta o un enlace repetido no crea filas paralelas.
library;

import 'dart:convert';

import '../domain/persona_example.dart';
import 'persona_repository.dart';
import 'personal_learning_text.dart';
import 'personal_reply_correction_memory.dart';
import 'personal_reply_variants.dart';

enum PersonalReplyLearningResult { created, merged, unchanged, rejected }

final class PersonalReplyLearningService {
  PersonalReplyLearningService({PersonaRepository? repository})
    : _repository = repository ?? PersonaRepository.instance;

  static final instance = PersonalReplyLearningService();
  static const _automaticSources = {
    'whatsapp_manual_learned',
    'messaging_center_learning',
    'correction',
  };

  final PersonaRepository _repository;

  /// Guarda sólo evidencia real: texto entrante y respuesta ya enviada.
  /// Si la entrada existe, agrega una variante única y elimina filas repetidas.
  Future<PersonalReplyLearningResult> learnVerifiedReply({
    required String incomingText,
    required String replyText,
    required String source,
    String? correctedFrom,
  }) async {
    final incoming = incomingText.trim();
    final reply = replyText.trim();
    if (incoming.isEmpty || reply.isEmpty) {
      return PersonalReplyLearningResult.rejected;
    }

    final all = await _repository.listExamples(limit: 200, scopeKey: 'owner');
    final key = promptKey(incoming);
    final matches = all
        .where((example) => promptKey(example.incomingText) == key)
        .toList();

    if (matches.isEmpty) {
      final created = await _repository.addExample(
        personaKey: 'owner',
        incomingText: incoming,
        body: reply,
        source: source,
        tone: _toneFor(
          base: const {},
          incoming: incoming,
          replies: [reply],
          correctedFrom: correctedFrom,
        ),
      );
      if (created && correctedFrom != null) {
        await PersonalReplyCorrectionMemory(_repository).remember(
          incoming: incoming,
          reply: reply,
          correctedFrom: correctedFrom,
        );
      }
      return created
          ? PersonalReplyLearningResult.created
          : PersonalReplyLearningResult.rejected;
    }

    final changed = await _mergeMatches(
      matches,
      incoming: incoming,
      newestReply: reply,
      correctedFrom: correctedFrom,
    );
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

  /// Repara datos creados por la lógica anterior sin tocar ejemplos manuales
  /// que no estén relacionados con aprendizaje automático.
  Future<int> consolidateExisting() async {
    final all = await _repository.listExamples(limit: 200, scopeKey: 'owner');
    final groups = <String, List<PersonaExample>>{};
    for (final example in all.where((item) => item.isPaired)) {
      groups
          .putIfAbsent(promptKey(example.incomingText), () => [])
          .add(example);
    }

    var repaired = 0;
    for (final group in groups.values) {
      final wasAutomaticallyDuplicated =
          group.length > 1 &&
          group.any((item) => _automaticSources.contains(item.source));
      if (!wasAutomaticallyDuplicated) continue;
      if (await _mergeMatches(group, incoming: group.first.incomingText)) {
        repaired++;
      }
    }
    return repaired;
  }

  Future<bool> _mergeMatches(
    List<PersonaExample> matches, {
    required String incoming,
    String? newestReply,
    String? correctedFrom,
  }) async {
    // Una fila manual conserva su categoría; si no existe, gana la más reciente.
    final keeper = matches.firstWhere(
      (item) => item.source == 'manual',
      orElse: () => matches.first,
    );
    final replies = <String>[
      if (newestReply != null) newestReply,
      for (final item in matches) ...item.variants,
    ];
    final uniqueReplies = uniqueLearningReplies(replies);
    final previous = uniqueLearningReplies(keeper.variants);
    final tone = _toneFor(
      base: keeper.tone,
      incoming: incoming,
      replies: uniqueReplies,
      correctedFrom: correctedFrom,
    );
    final changed =
        matches.length > 1 ||
        !sameLearningReplies(previous, uniqueReplies) ||
        keeper.tone['ownerVerified'] != 'true';
    if (!changed) return false;

    await _repository.updateExample(
      keeper,
      body: uniqueReplies.first,
      incomingText: incoming,
      tone: tone,
    );
    for (final duplicate in matches.where((item) => item.id != keeper.id)) {
      await _repository.deleteExample(duplicate.id);
    }
    return true;
  }

  Map<String, String> _toneFor({
    required Map<String, String> base,
    required String incoming,
    required List<String> replies,
    String? correctedFrom,
  }) {
    final bounded = fitLearningMetadata(replies);
    return {
      ...base,
      'ownerVerified': 'true',
      'kind': 'paired',
      'incomingVariants': jsonEncode([incoming]),
      'variants': jsonEncode(bounded),
      'responses': jsonEncode(
        bounded
            .map((text) => PersonaResponseOption(text: text).toMap())
            .toList(),
      ),
      if (correctedFrom != null) 'correctedFrom': correctedFrom,
    };
  }

  static String promptKey(String raw) => normalizePersonalLearningText(raw);

  static String replyKey(String raw) => promptKey(raw);
}
