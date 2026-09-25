// QUÉ HACE: recorre y consolida el catálogo persistido por sección.
// CÓMO: pagina SQLite, elimina ruido automático y fusiona disparadores iguales.
// POR QUÉ: evita que el límite de 200 filas deje duplicados antiguos sin reparar.

part of 'personal_reply_learning_service.dart';

extension _PersonalReplyLearningConsolidation on PersonalReplyLearningService {
  Future<List<PersonaExample>> _allExamples(String scopeKey) async {
    const pageSize = 200;
    const maximum = 5000;
    final all = <PersonaExample>[];
    while (all.length < maximum) {
      final page = await _repository.listExamples(
        limit: pageSize,
        offset: all.length,
        scopeKey: scopeKey,
      );
      all.addAll(page);
      if (page.length < pageSize) break;
    }
    return all;
  }

  Future<int> _consolidateScope(String scopeKey) async {
    final all = await _allExamples(scopeKey);
    final removed = <int>{};
    var repaired = 0;

    // Solo datos automáticos/importados se eliminan sin intervención manual.
    for (final example in all.where(
      (item) =>
          PersonalReplyLearningService._automaticSources.contains(
            item.source,
          ) &&
          !isLearnablePersonalPrompt(item.incomingText),
    )) {
      await _repository.deleteExample(example.id);
      removed.add(example.id);
      repaired++;
    }

    final groups = <String, List<PersonaExample>>{};
    for (final example in all.where(
      (item) =>
          !removed.contains(item.id) &&
          item.isPaired &&
          isLearnablePersonalPrompt(item.incomingText),
    )) {
      groups
          .putIfAbsent(
            PersonalReplyLearningService.promptKey(example.incomingText),
            () => [],
          )
          .add(example);
    }

    for (final group in groups.values) {
      if (group.length < 2) continue;
      if (await _mergeMatches(group, incoming: group.first.incomingText)) {
        repaired++;
      }
    }
    return repaired;
  }
}
