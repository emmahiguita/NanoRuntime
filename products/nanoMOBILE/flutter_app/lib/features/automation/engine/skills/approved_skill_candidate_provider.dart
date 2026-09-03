/// SKILL-CONS-01 — ApprovedSkillCandidateProvider: consumidor de skills
/// aprobadas en el planner Candidate-First.
///
/// Puente VerifiedSkill → NanoSkill (A13). Una skill aprobada por el usuario
/// (hecho humano explícito) habilita su NanoSkill concreto para cualquier
/// goal que ese skill pueda atender. El provider se consulta ANTES que el
/// resto de fuentes: la cobertura verificada llega primero al pool.
///
/// Por qué NO se casa por goalFingerprint: el journal del camino
/// Candidate-First firma el plan post-hoc (`{'plan': planSignature}`), no el
/// texto del goal — en tiempo de planificación ese fingerprint todavía no
/// existe. La skill aprobada se consume por su ACCIÓN semántica (el usuario
/// aprobó "Nano sabe hacer openApp así"), y la aplicabilidad al goal la
/// decide el propio NanoSkill (canHandle/candidates sobre los mismos
/// catálogos grounded).
///
/// NO es un atajo: los candidatos entran al MISMO pool → selection (A6) →
/// governance (A11) → dispatcher → verifier. La skill solo aporta cobertura
/// con precedencia de proveniencia verificada; no salta política ni
/// autorización.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../planning/candidates/candidate_action.dart';
import '../planning/candidates/candidate_provider.dart';
import 'nano_skill.dart';
import 'skill.dart';
import 'skill_store.dart';

/// Resuelve la implementación [NanoSkill] para una acción semántica del
/// vocabulario. null = sin puente concreto (honesto: jamás se inventan
/// bridges para acciones sin skill real).
typedef SkillResolver = NanoSkill? Function(String semanticAction);

final class ApprovedSkillCandidateProvider implements CandidateProvider {
  ApprovedSkillCandidateProvider(this._store, this._resolver);

  final SkillStore _store;
  final SkillResolver _resolver;

  @override
  String get id => 'approved_skill';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final approved = _store.approved();
    if (approved.isEmpty) return const [];
    final out = <CandidateAction>[];
    for (final verified in approved) {
      final semanticAction = _primaryAction(verified.skill);
      if (semanticAction.isEmpty) continue;
      final nanoSkill = _resolver(semanticAction);
      if (nanoSkill == null) continue;
      try {
        final candidates = await nanoSkill.candidates(
          SkillContext(request.goal),
        );
        if (candidates.isNotEmpty) {
          debugPrint(
            '[skills] consumidor: "${verified.skill.id}" cubre el goal '
            'con ${candidates.length} candidatos grounded',
          );
          out.addAll(candidates);
        }
      } on Object catch (error) {
        // Fallo aislado: una skill rota no destruye la generación (mismo
        // contrato que el resto de providers).
        debugPrint('[skills] consumidor: "${verified.skill.id}" falló: $error');
      }
    }
    return out;
  }

  /// Acción principal del skill: primer paso del vocabulario semántico. El id
  /// es 'skill:<acción>' (estable), pero los pasos son la fuente tipada.
  static String _primaryAction(Skill skill) {
    if (skill.steps.isNotEmpty && skill.steps.first.semanticAction.isNotEmpty) {
      return skill.steps.first.semanticAction;
    }
    const prefix = 'skill:';
    return skill.id.startsWith(prefix) ? skill.id.substring(prefix.length) : '';
  }
}
