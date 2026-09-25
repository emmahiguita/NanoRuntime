// QUÉ HACE: conserva observaciones pendientes y fusiona aprendizaje real.
// CÓMO: aplica TTL a observaciones pasivas y actualiza una sola fila por intención.
// POR QUÉ: separa persistencia de señales y evita duplicados en el servicio principal.

part of 'personal_reply_learning_service.dart';

extension PersonalReplyLearningFlow on PersonalReplyLearningService {
  Future<int> _recordPersistentObservation({
    required String patternFingerprint,
    required String responseFingerprint,
    required String incoming,
    required String reply,
    required String source,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final memCount = (_passiveSignalCountByKey[patternFingerprint] ?? 0) + 1;
    _passiveSignalCountByKey[patternFingerprint] = memCount;
    try {
      final observations = await _repository.listPersonalMemories(
        scopeKey: PersonalReplyLearningService._observationScope,
        limit: 120,
      );
      for (final obs in observations.where((o) => o.expired && o.id >= 0)) {
        await _repository.deletePersonalMemory(obs.id);
      }
      final existing = observations
          .where((o) => !o.expired && o.key == patternFingerprint)
          .firstOrNull;
      final prevCount =
          int.tryParse(existing?.metadata['count'] ?? '') ?? (memCount - 1);
      final nextCount = prevCount + 1;
      final firstSeen =
          int.tryParse(existing?.metadata['firstSeenAt'] ?? '') ?? now;
      if (existing != null && existing.id >= 0) {
        await _repository.deletePersonalMemory(existing.id);
      }
      if (nextCount < 2) {
        await _repository.savePersonalMemory(
          PersonalMemory(
            scopeKey: PersonalReplyLearningService._observationScope,
            key: patternFingerprint,
            value: reply,
            kind: 'pendingObservation',
            observedAt: now,
            metadata: {
              'patternFingerprint': patternFingerprint,
              'responseFingerprint': responseFingerprint,
              'incoming': incoming,
              'count': '$nextCount',
              'firstSeenAt': '$firstSeen',
              'lastSeenAt': '$now',
              'expiresAt':
                  '${now + PersonalReplyLearningService._observationTtlMs}',
              'source': source,
            },
          ),
        );
      }
      _passiveSignalCountByKey[patternFingerprint] = nextCount;
      return nextCount;
    } catch (_) {
      return memCount;
    }
  }

  Future<int> consolidateExisting() async {
    final summary = await _repository.personalizationSummary();
    final scopes = <String>{'owner'};
    for (final value in (summary['scopeKeys'] as List? ?? const [])) {
      final scope = value.toString().trim();
      if (scope.isNotEmpty) scopes.add(scope);
    }
    var repaired = 0;
    for (final scope in scopes) {
      repaired += await _consolidateScope(scope);
    }
    return repaired;
  }

  Future<bool> _mergeMatches(
    List<PersonaExample> matches, {
    required String incoming,
    String? newestReply,
    ReplyProvenance provenance = ReplyProvenance.humanPassiveObservation,
    String? correctedFrom,
  }) async {
    final keeper = matches.firstWhere(
      (item) => item.source == 'manual',
      orElse: () => matches.first,
    );
    final replies = <String>[
      if (newestReply != null) newestReply,
      for (final item in matches) ...item.variants,
    ];
    final incomingVariants = uniqueLearningReplies([
      incoming,
      for (final item in matches) ...item.incomingVariants,
    ]);
    final uniqueReplies = uniqueLearningReplies(replies);
    final previous = uniqueLearningReplies(keeper.variants);
    final previousIncoming = uniqueLearningReplies(keeper.incomingVariants);
    final tone = _learningToneFor(
      base: keeper.tone,
      incoming: incoming,
      incomingVariants: incomingVariants,
      replies: uniqueReplies,
      provenance: provenance,
      correctedFrom: correctedFrom,
    );
    final changed =
        matches.length > 1 ||
        !sameLearningReplies(previous, uniqueReplies) ||
        !sameLearningReplies(previousIncoming, incomingVariants) ||
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
}
