/// SKILL-01 — SkillExtractor: convierte trazas VERIFICADAS del
/// ExecutionJournal en drafts de skills semánticas.
///
/// Reglas duras:
/// - SOLO entradas con status verified y con [ExecutionJournalEntry.semanticAction]
///   dentro del vocabulario ([kTaskSemanticActionNames]). outcomeUnknown,
///   failed, completedUnverified o trazas tool-directas (semanticAction vacío)
///   → null. Jamás se genera una skill de una traza incierta.
/// - Pre/postcondiciones derivan de la política semántica canónica
///   ([semanticActionDefinition]): el extractor no inventa condiciones.
/// - El draft NO es ejecutable: requiere aprobación explícita del usuario
///   ([VerifiedSkill]) y, aun aprobada, su ejecución pasará por el MISMO
///   Policy → Journal → CommitGuard. Skills no son un atajo.
library;

import '../governance/semantic_policy.dart';
import '../orchestration/execution_journal.dart';
import '../orchestration/task_step_vocabulary.dart';
import 'skill.dart';
import 'skill_store.dart';

abstract interface class SkillExtractor {
  /// Traza verificada → draft. null si la traza no califica.
  Skill? extract(ExecutionJournalEntry verifiedTrace);
}

/// Extractor sobre la política semántica canónica. Puro y determinista:
/// sin LLM, sin observación, sin escritura.
final class PolicySkillExtractor implements SkillExtractor {
  const PolicySkillExtractor();

  @override
  Skill? extract(ExecutionJournalEntry entry) {
    if (entry.status != ExecutionJournalStatus.verified) return null;
    final action = entry.semanticAction;
    if (action.isEmpty) return null;
    final definition = semanticActionDefinition(action);
    if (definition == null) {
      // Fuera del vocabulario finito: jamás se genera una skill libre.
      return null;
    }

    final preconditions = <SkillCondition>[
      for (final input in definition.requiredInputs)
        SkillCondition(kind: SkillConditionKind.input, name: input),
      if (definition.requiresConfirmation)
        const SkillCondition(
          kind: SkillConditionKind.confirmation,
          name: 'confirmación humana explícita',
        ),
      if (definition.requiresContextLock)
        const SkillCondition(
          kind: SkillConditionKind.contextLock,
          name: 'contexto bloqueado contra cambios',
        ),
    ];
    final expectedPostconditions = [
      definition.requiredEvidence == RequiredEvidence.verified
          ? const SkillCondition(
              kind: SkillConditionKind.effectVerified,
              name: 'efecto verificado contra el estado real',
            )
          : const SkillCondition(
              kind: SkillConditionKind.effectExecuted,
              name: 'acción ejecutada sin verificación de efecto',
            ),
    ];

    return Skill(
      id: Skill.idFor(action),
      preconditions: preconditions,
      steps: [
        SemanticSkillStep(
          semanticAction: action,
          inputs: definition.requiredInputs,
        ),
      ],
      expectedPostconditions: expectedPostconditions,
      sourceRunId: entry.runId,
      goalFingerprint: entry.goalFingerprint,
      extractedAt: DateTime.now().toUtc(),
    );
  }
}

/// Recolector: puente entre el journal (o el hook post-verificado del
/// TaskOrchestrator) y el [SkillStore]. Best-effort por diseño: la
/// recolección jamás falla la tarea que la origina.
final class SkillCollector {
  const SkillCollector({required this.extractor, required this.store});

  final SkillExtractor extractor;
  final SkillStore store;

  /// Convierte UNA traza verificada en draft. false si no califica.
  Future<bool> collectEntry(ExecutionJournalEntry entry) async {
    final skill = extractor.extract(entry);
    if (skill == null) return false;
    await store.saveDraft(skill);
    return true;
  }

  /// Barre el journal completo (traza tras traza). Devuelve cuántos drafts
  /// nuevos se guardaron. Útil para reconstruir drafts tras un arranque.
  Future<int> collectAll(ExecutionJournal journal) async {
    var collected = 0;
    for (final entry in await journal.all()) {
      if (await collectEntry(entry)) collected++;
    }
    return collected;
  }
}
