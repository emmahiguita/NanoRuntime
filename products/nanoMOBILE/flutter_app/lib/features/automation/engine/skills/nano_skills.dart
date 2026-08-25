/// Skills concretos (A13) — capacidades de alto nivel que producen candidatos
/// grounded reusando la infraestructura A6 (providers/catálogos). Nunca crean
/// ToolCall directo ni ejecutan; el governance (A11) y el dispatcher lo hacen.
library;

import '../planning/candidates/candidate_action.dart';
import '../planning/candidates/candidate_provider.dart';
import '../planning/candidates/candidate_providers.dart';
import '../planning/deterministic_catalog.dart';
import '../system/installed_app_catalog.dart';
import '../system/system_graph.dart';
import '../system/system_intent_catalog.dart';
import 'nano_skill.dart';

/// "abre <app>" → launch_app grounded en el catálogo.
class OpenAppSkill implements NanoSkill {
  OpenAppSkill(this._catalog);

  final InstalledAppCatalog _catalog;

  @override
  String get id => 'open_app';

  @override
  Future<bool> canHandle(SkillContext context) async {
    final candidates = await _provide(context.goal);
    return candidates.isNotEmpty;
  }

  @override
  Future<List<CandidateAction>> candidates(SkillContext context) =>
      _provide(context.goal);

  Future<List<CandidateAction>> _provide(String goal) =>
      InstalledAppCandidateProvider(_catalog).provide(CandidateRequest(goal));
}

/// "abre Bluetooth/Wi-Fi/ajustes" → open_system grounded (allowlist A3).
class SystemNavigationSkill implements NanoSkill {
  SystemNavigationSkill(this._catalog, this._graph, this._intents);

  final DeterministicFlowCatalog _catalog;
  final SystemGraph _graph;
  final SystemIntentCatalog _intents;

  @override
  String get id => 'system_navigation';

  @override
  Future<bool> canHandle(SkillContext context) async {
    final candidates = await _provide(context.goal);
    return candidates.isNotEmpty;
  }

  @override
  Future<List<CandidateAction>> candidates(SkillContext context) =>
      _provide(context.goal);

  Future<List<CandidateAction>> _provide(String goal) =>
      SystemIntentCandidateProvider(
        _catalog,
        _graph,
        _intents,
      ).provide(CandidateRequest(goal));
}

/// "lee notificaciones" → notifications (read).
class ReadNotificationsSkill implements NanoSkill {
  ReadNotificationsSkill(this._catalog);

  final DeterministicFlowCatalog _catalog;

  @override
  String get id => 'read_notifications';

  @override
  Future<bool> canHandle(SkillContext context) async {
    final candidates = await _provide(context.goal);
    return candidates.isNotEmpty;
  }

  @override
  Future<List<CandidateAction>> candidates(SkillContext context) =>
      _provide(context.goal);

  Future<List<CandidateAction>> _provide(String goal) async {
    final all = await DeterministicCandidateProvider(
      _catalog,
    ).provide(CandidateRequest(goal));
    return all.where((c) => c.tool == 'notifications').toList();
  }
}
