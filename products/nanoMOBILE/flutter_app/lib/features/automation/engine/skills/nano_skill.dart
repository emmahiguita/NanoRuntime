/// NanoSkill (A13) — contrato de capacidad de alto nivel.
///
/// Un skill NO es texto arbitrario ejecutable ni `runRawShell`. Produce
/// [CandidateAction] grounded (reusa providers/catálogos). El skill encapsula
/// el "saber hacer" de un dominio; la ejecución sigue pasando por governance
/// (A11) + dispatcher + verifier.
library;

import '../planning/candidates/candidate_action.dart';

class SkillContext {
  final String goal;
  const SkillContext(this.goal);
}

abstract interface class NanoSkill {
  String get id;

  /// ¿Este skill puede atender el goal?
  Future<bool> canHandle(SkillContext context);

  /// Candidatos grounded que el skill puede producir para el goal.
  Future<List<CandidateAction>> candidates(SkillContext context);
}
