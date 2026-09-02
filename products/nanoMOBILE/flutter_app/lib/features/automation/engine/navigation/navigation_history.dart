/// Historial acotado de navegación perteneciente a un AutomationRun.
library;

import 'dart:convert';

import '../perception/current_situation.dart';
import 'navigation_decision.dart';
import 'navigation_goal.dart';

/// Límites duros para una navegación orientada a objetivos.
final class NavigationBudget {
  factory NavigationBudget({
    int maxNavigationSteps = 8,
    int maxSameStateObservations = 2,
    int maxBackTransitions = 3,
  }) {
    if (maxNavigationSteps <= 0) {
      throw ArgumentError.value(maxNavigationSteps, 'maxNavigationSteps');
    }
    if (maxSameStateObservations <= 1) {
      throw ArgumentError.value(
        maxSameStateObservations,
        'maxSameStateObservations',
      );
    }
    if (maxBackTransitions <= 0) {
      throw ArgumentError.value(maxBackTransitions, 'maxBackTransitions');
    }
    return NavigationBudget._(
      maxNavigationSteps: maxNavigationSteps,
      maxSameStateObservations: maxSameStateObservations,
      maxBackTransitions: maxBackTransitions,
    );
  }

  const NavigationBudget._({
    required this.maxNavigationSteps,
    required this.maxSameStateObservations,
    required this.maxBackTransitions,
  });

  static const standard = NavigationBudget._(
    maxNavigationSteps: 8,
    maxSameStateObservations: 2,
    maxBackTransitions: 3,
  );

  final int maxNavigationSteps;
  final int maxSameStateObservations;
  final int maxBackTransitions;
}

enum NavigationProgressStatus { proceed, stalled, budgetExhausted }

final class NavigationProgress {
  const NavigationProgress._(this.status, this.reason);

  const NavigationProgress.proceed()
    : this._(NavigationProgressStatus.proceed, 'navegación dentro del límite');

  const NavigationProgress.stalled(String reason)
    : this._(NavigationProgressStatus.stalled, reason);

  const NavigationProgress.budgetExhausted(String reason)
    : this._(NavigationProgressStatus.budgetExhausted, reason);

  final NavigationProgressStatus status;
  final String reason;

  bool get mayAct => status == NavigationProgressStatus.proceed;
}

final class NavigationHistoryEntry {
  const NavigationHistoryEntry({
    required this.goalSignature,
    required this.situationSignature,
    required this.action,
  });

  final String goalSignature;
  final String situationSignature;
  final NavigationAction action;

  NavigationActionKind get actionKind => action.kind;
}

/// Owner del progreso observado durante una única ejecución.
///
/// Solo contabiliza acciones que pudieron haber sido despachadas. Nunca
/// ejecuta, decide ni transforma un estado incierto en éxito.
final class NavigationHistory {
  NavigationHistory({this.budget = NavigationBudget.standard});

  final NavigationBudget budget;
  final List<NavigationHistoryEntry> _entries = [];
  int _navigationSteps = 0;
  int _backTransitions = 0;

  List<NavigationHistoryEntry> get entries => List.unmodifiable(_entries);
  NavigationHistoryEntry? get lastEntry =>
      _entries.isEmpty ? null : _entries.last;
  int get navigationSteps => _navigationSteps;
  int get backTransitions => _backTransitions;

  /// Comprueba si una nueva acción puede intentarse, sin consumir presupuesto.
  /// La reserva se confirma mediante [recordAttempted] únicamente después de
  /// que el ejecutor haya aceptado el intento.
  NavigationProgress assess({
    required CurrentSituation situation,
    required NavigationGoal goal,
    required NavigationDecision decision,
    required bool transitionUnchanged,
  }) {
    if (decision.status != NavigationDecisionStatus.act) {
      return const NavigationProgress.proceed();
    }
    final action = decision.action!;
    final goalSignature = navigationGoalSignature(goal);
    final candidate = NavigationHistoryEntry(
      goalSignature: goalSignature,
      situationSignature: situation.screenSignature,
      action: action,
    );

    final sameState = transitionUnchanged
        ? _consecutiveSameState(candidate)
        : 1;
    if (transitionUnchanged && sameState >= budget.maxSameStateObservations) {
      return NavigationProgress.stalled(
        'navegación detenida: la misma situación fue observada '
        '$sameState veces sin progreso',
      );
    }
    if (_hasAlternatingCycle(candidate)) {
      return const NavigationProgress.stalled(
        'navegación detenida: ciclo alternante A → B → A → B',
      );
    }
    if (_navigationSteps >= budget.maxNavigationSteps) {
      return NavigationProgress.budgetExhausted(
        'navegación detenida: límite de ${budget.maxNavigationSteps} '
        'acciones alcanzado',
      );
    }
    if (action.kind == NavigationActionKind.back &&
        _backTransitions >= budget.maxBackTransitions) {
      return NavigationProgress.budgetExhausted(
        'navegación detenida: límite de ${budget.maxBackTransitions} '
        'transiciones BACK alcanzado',
      );
    }

    return const NavigationProgress.proceed();
  }

  void recordAttempted({
    required CurrentSituation situation,
    required NavigationGoal goal,
    required NavigationDecision decision,
  }) {
    if (decision.status != NavigationDecisionStatus.act ||
        decision.action == null) {
      throw ArgumentError('Solo una decisión act puede registrarse.');
    }
    final entry = NavigationHistoryEntry(
      goalSignature: navigationGoalSignature(goal),
      situationSignature: situation.screenSignature,
      action: decision.action!,
    );
    _entries.add(entry);
    _navigationSteps++;
    if (entry.actionKind == NavigationActionKind.back) _backTransitions++;
  }

  int _consecutiveSameState(NavigationHistoryEntry current) {
    var count = 1;
    for (var index = _entries.length - 1; index >= 0; index--) {
      final observed = _entries[index];
      if (observed.goalSignature != current.goalSignature ||
          observed.situationSignature != current.situationSignature) {
        break;
      }
      count++;
    }
    return count;
  }

  bool _hasAlternatingCycle(NavigationHistoryEntry candidate) {
    if (_entries.length < 3) return false;
    final tail = [..._entries.sublist(_entries.length - 3), candidate];
    if (tail.any((entry) => entry.goalSignature != candidate.goalSignature)) {
      return false;
    }
    final a = tail[0].situationSignature;
    final b = tail[1].situationSignature;
    return a != b &&
        a == tail[2].situationSignature &&
        b == tail[3].situationSignature;
  }
}

String navigationGoalSignature(NavigationGoal goal) => jsonEncode({
  'package': goal.targetPackage,
  'surface': goal.targetSurface.name,
  'entity': goal.targetEntity?.trim().toLowerCase(),
});
