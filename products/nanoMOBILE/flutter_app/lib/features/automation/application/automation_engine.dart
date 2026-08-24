/// AutomationEngine — la superficie PÚBLICA del módulo de automatización.
///
/// Responde a la pregunta del producto de forma legible:
///   "Dado un objetivo, lo convierto en acciones verificadas sobre
///    Android/Linux, y aprendo de lo que funciona."
///
/// Es una FACADE FINA sobre el [AutomationCoordinator] (la implementación).
/// Quien entra al módulo ve estas 3 operaciones y entiende qué hace; la
/// maquinaria (planner → router → policy → executor → verifier → memory) vive
/// detrás, documentada en `docs/automatizacion.md`.
///
/// Fuentes de objetivos (chat, notificaciones, voz, eventos, scheduler) usan
/// ESTE engine; no tocan el coordinator ni el dispatcher.
library;

import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/ledger/action_ledger.dart';
import 'package:nanoai/features/automation/ledger/automation_trace.dart';

import 'automation_coordinator.dart';

class AutomationEngine {
  final AutomationCoordinator _coordinator;
  final ActionLedger _ledger;

  const AutomationEngine._(this._coordinator, this._ledger);

  /// Construye el engine real sobre el coordinator + ledger compartido.
  static AutomationEngine from(
    AutomationCoordinator coordinator,
    ActionLedger ledger,
  ) => AutomationEngine._(coordinator, ledger);

  /// EL objetivo → acciones verificadas → [AutomationResult] honesto.
  ///
  /// Nunca inventa éxito: completed / completedUnverified / paused / denied /
  /// noPlan / failed / cancelled. El motor decide el camino (flujo verificado
  /// en cache → determinista, si no → planner LLM local → ejecuta → verifica
  /// → aprende solo de éxitos verificados).
  Future<AutomationResult> runGoal(AutomationGoal goal) =>
      _coordinator.execute(goal);

  /// Qué hizo REALMENTE el motor (trazas del ledger, recientes primero).
  List<AutomationTrace> trace() => _ledger.entries;

  /// Trazas de un objetivo concreto (para auditar/depurar un flujo).
  List<AutomationTrace> traceOf(String goal) => _ledger.forGoal(goal);
}
