/// SKILL-01 — Skill: modelo tipado de una skill SEMÁNTICA reutilizable,
/// extraída SOLO de trazas verificadas del ExecutionJournal. Nunca taps
/// crudos, coordenadas ni comandos: cada paso es una acción del vocabulario
/// finito ([kTaskSemanticActionNames]) y las condiciones derivan de la
/// política semántica canónica.
///
/// Una skill es un DRAFT hasta que el usuario la aprueba explícitamente
/// ([VerifiedSkill]). Jamás se ejecuta por su cuenta.
library;

/// Tipo de condición de una skill. Derivada de la política, no inventada.
enum SkillConditionKind {
  /// El paso consume un input tipado (requiredInputs de la semántica).
  input,

  /// La semántica exige confirmación humana explícita.
  confirmation,

  /// La semántica exige contexto bloqueado contra cambios.
  contextLock,

  /// Postcondición: el efecto se verificó contra el estado real.
  effectVerified,

  /// Postcondición: la acción se ejecutó sin verificación de efecto.
  effectExecuted,
}

/// Condición legible (semántica, no técnica): el usuario aprueba lo que
/// entiende, no hashes ni coordenadas.
final class SkillCondition {
  final SkillConditionKind kind;
  final String name;

  const SkillCondition({required this.kind, required this.name});

  Map<String, Object?> toJson() => {'kind': kind.name, 'name': name};

  factory SkillCondition.fromJson(Map<String, dynamic> m) => SkillCondition(
    kind: SkillConditionKind.values.byName(m['kind'] as String),
    name: (m['name'] as String?) ?? '',
  );
}

/// Paso semántico de la skill: acción del vocabulario + sus inputs tipados.
final class SemanticSkillStep {
  final String semanticAction;

  /// Inputs requeridos por la semántica (nombres, no valores).
  final List<String> inputs;

  const SemanticSkillStep({required this.semanticAction, this.inputs = const []});

  Map<String, Object?> toJson() => {
    'action': semanticAction,
    'inputs': inputs,
  };

  factory SemanticSkillStep.fromJson(Map<String, dynamic> m) =>
      SemanticSkillStep(
        semanticAction: (m['action'] as String?) ?? '',
        inputs: [
          for (final i in (m['inputs'] as List?) ?? const []) '$i',
        ],
      );
}

/// Skill inmutable. [id] estable por acción semántica: una nueva traza
/// verificada de la misma acción reemplaza el draft anterior (la evidencia
/// más reciente gana).
final class Skill {
  final String id;
  final List<SkillCondition> preconditions;
  final List<SemanticSkillStep> steps;
  final List<SkillCondition> expectedPostconditions;

  /// Procedencia factual: run, plan y momento de la traza que la originó.
  final String sourceRunId;
  final String goalFingerprint;
  final DateTime extractedAt;

  const Skill({
    required this.id,
    required this.preconditions,
    required this.steps,
    required this.expectedPostconditions,
    required this.sourceRunId,
    required this.goalFingerprint,
    required this.extractedAt,
  });

  /// Id estable por acción semántica.
  static String idFor(String semanticAction) => 'skill:$semanticAction';

  Map<String, Object?> toJson() => {
    'id': id,
    'preconditions': [for (final c in preconditions) c.toJson()],
    'steps': [for (final s in steps) s.toJson()],
    'expectedPostconditions': [
      for (final c in expectedPostconditions) c.toJson(),
    ],
    'sourceRunId': sourceRunId,
    'goalFingerprint': goalFingerprint,
    'extractedAt': extractedAt.toUtc().toIso8601String(),
  };

  factory Skill.fromJson(Map<String, dynamic> m) => Skill(
    id: (m['id'] as String?) ?? '',
    preconditions: [
      for (final c in (m['preconditions'] as List?) ?? const [])
        SkillCondition.fromJson((c as Map).cast<String, dynamic>()),
    ],
    steps: [
      for (final s in (m['steps'] as List?) ?? const [])
        SemanticSkillStep.fromJson((s as Map).cast<String, dynamic>()),
    ],
    expectedPostconditions: [
      for (final c in (m['expectedPostconditions'] as List?) ?? const [])
        SkillCondition.fromJson((c as Map).cast<String, dynamic>()),
    ],
    sourceRunId: (m['sourceRunId'] as String?) ?? '',
    goalFingerprint: (m['goalFingerprint'] as String?) ?? '',
    extractedAt: DateTime.parse(m['extractedAt'] as String).toUtc(),
  );
}
