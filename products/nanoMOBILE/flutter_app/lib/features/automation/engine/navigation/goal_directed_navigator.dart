/// Navegador puro orientado al estado objetivo.
library;

import '../perception/current_situation.dart';
import '../perception/semantic/nano_ui_object.dart';
import '../perception/semantic/semantic_role.dart';
import '../perception/surface_resolvers.dart';
import 'navigation_decision.dart';
import 'navigation_goal.dart';
import 'situation_diff.dart';

/// Observa un [CurrentSituation] ya clasificado y decide como máximo una acción.
/// No ejecuta IO, no modifica estado y no produce secuencias procedurales.
final class GoalDirectedNavigator {
  const GoalDirectedNavigator();

  NavigationDecision decide(CurrentSituation current, NavigationGoal goal) {
    final observedCurrent = _groundTargetEntity(current, goal.targetEntity);
    final diff = SituationDiff.between(observedCurrent, goal);
    if (diff.matchesTarget) return NavigationDecision.arrived(diff);

    final packageDifference = diff.differences.firstWhere(
      (difference) => difference.dimension == SituationDimension.packageName,
    );
    if (packageDifference.comparison == SituationComparison.mismatch) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.launchPackage(goal.targetPackage),
        reason: 'paquete actual distinto del destino',
      );
    }
    if (packageDifference.comparison == SituationComparison.unknown) {
      return NavigationDecision.needsMoreEvidence(
        diff,
        'paquete actual no observable',
      );
    }

    final targetEntity = goal.targetEntity;
    if (targetEntity == null) {
      return NavigationDecision.needsMoreEvidence(
        diff,
        'no existe una transición universal para la superficie solicitada',
      );
    }

    final targetSelectors = _actionableEntitySelectors(
      observedCurrent,
      targetEntity,
    );
    if (targetSelectors.length == 1) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.tap(targetSelectors.single),
        reason: 'entidad objetivo accionable y observada',
      );
    }
    if (targetSelectors.length > 1) {
      return NavigationDecision.needsMoreEvidence(
        diff,
        'entidad objetivo ambigua en la superficie actual',
      );
    }

    final graph = observedCurrent.structuralEvidence;
    final searchInput = const InputSurfaceResolver().resolve(
      graph,
      kind: InputSurfaceKind.search,
    );
    if (searchInput != null) {
      if (_sameEntity(searchInput.object.text, targetEntity)) {
        return NavigationDecision.needsMoreEvidence(
          diff,
          'búsqueda ya contiene la entidad pero el resultado no es accionable',
        );
      }
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.write(searchInput.selector, targetEntity),
        reason: 'campo de búsqueda observado',
      );
    }

    if (observedCurrent.surfaceKind == goal.targetSurface) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.back(),
        reason: 'identidad objetivo no demostrada en la superficie actual',
      );
    }

    final searchAction = const ActionSurfaceResolver().resolve(
      graph,
      kind: 'search',
    );
    if (searchAction != null) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.tap(searchAction.selector),
        reason: 'entrada de búsqueda observada',
      );
    }

    return NavigationDecision.needsMoreEvidence(
      diff,
      'sin acción grounded que reduzca la diferencia',
    );
  }

  CurrentSituation _groundTargetEntity(
    CurrentSituation current,
    String? targetEntity,
  ) {
    if (current.entity != null || targetEntity == null) return current;
    for (final object in current.structuralEvidence.objects) {
      if (!object.visible ||
          object.evidence.isEmpty ||
          !_objectNamesEntity(object, targetEntity) ||
          !_belongsToToolbar(current, object)) {
        continue;
      }
      return CurrentSituation(
        structuralEvidence: current.structuralEvidence,
        surfaceKind: current.surfaceKind,
        classificationEvidence: current.classificationEvidence,
        entity: targetEntity,
        entityEvidence: [_evidenceFor(object)],
        observedAt: current.observedAt,
      );
    }
    return current;
  }

  List<String> _actionableEntitySelectors(
    CurrentSituation current,
    String targetEntity,
  ) {
    final graph = current.structuralEvidence;
    final selectors = <String>{};
    for (final object in graph.objects) {
      if (!object.visible || !_objectNamesEntity(object, targetEntity)) {
        continue;
      }
      var target = object;
      for (var depth = 0; depth < 4; depth++) {
        if (target.visible && target.enabled && target.clickable) break;
        final parent = graph.parentOf(target.id);
        if (parent == null) break;
        target = parent;
      }
      if (!target.visible || !target.enabled || !target.clickable) continue;
      // Conserva el ancla semántica exacta que identificó la entidad. El
      // executor resolverá este nodo en un snapshot fresco y subirá a su
      // ancestro clicable; usar el contenedor aquí degrada a etiquetas
      // genéricas como "android.widget.LinearLayout" y puede tocar otra fila.
      final selector = _entitySelectorFor(object, targetEntity);
      if (selector == null) continue;
      selectors.add(selector);
    }
    return List.unmodifiable(selectors);
  }

  String? _entitySelectorFor(NanoUiObject object, String targetEntity) {
    if (_sameEntity(object.text, targetEntity)) {
      return 'text=${object.text}';
    }
    if (_sameEntity(object.description, targetEntity)) {
      return 'desc=${object.description}';
    }
    if (_sameEntity(object.label, targetEntity)) {
      return 'text=${object.label}';
    }
    return null;
  }

  bool _belongsToToolbar(CurrentSituation current, NanoUiObject object) {
    if (object.role == SemanticRole.toolbar) return true;
    var ancestor = current.structuralEvidence.parentOf(object.id);
    for (var depth = 0; depth < 4 && ancestor != null; depth++) {
      if (ancestor.role == SemanticRole.toolbar) return true;
      ancestor = current.structuralEvidence.parentOf(ancestor.id);
    }
    return false;
  }

  SituationEvidence _evidenceFor(NanoUiObject object) => SituationEvidence(
    objectId: object.id,
    role: object.role,
    confidence: object.confidence,
    sources: object.evidence,
  );

  bool _objectNamesEntity(NanoUiObject object, String entity) => {
    object.label,
    object.text,
    object.description,
  }.any((candidate) => _sameEntity(candidate, entity));

  bool _sameEntity(String observed, String target) =>
      navigationEntityKey(observed) == navigationEntityKey(target);
}
