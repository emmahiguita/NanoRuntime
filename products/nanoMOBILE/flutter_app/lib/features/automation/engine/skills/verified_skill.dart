/// SKILL-01 — VerifiedSkill: estado de aprobación de una skill. Un draft
/// ([Skill]) NO es ejecutable; solo el usuario lo aprueba explícitamente y
/// entonces queda registrado como verified con su momento exacto.
///
/// La aprobación es un hecho humano: nunca se auto-aprueba.
library;

import 'skill.dart';

final class VerifiedSkill {
  final Skill skill;

  /// Instante de la aprobación explícita del usuario (UTC).
  final DateTime approvedAt;

  const VerifiedSkill({required this.skill, required this.approvedAt});

  Map<String, Object?> toJson() => {
    'skill': skill.toJson(),
    'approvedAt': approvedAt.toUtc().toIso8601String(),
  };

  factory VerifiedSkill.fromJson(Map<String, dynamic> m) => VerifiedSkill(
    skill: Skill.fromJson((m['skill'] as Map).cast<String, dynamic>()),
    approvedAt: DateTime.parse(m['approvedAt'] as String).toUtc(),
  );
}
