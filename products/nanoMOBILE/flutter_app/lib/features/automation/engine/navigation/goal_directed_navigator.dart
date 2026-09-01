/// Navegador puro orientado al estado objetivo.
library;

import '../perception/current_situation.dart';
import '../perception/semantic/nano_ui_object.dart';
import '../perception/semantic/screen_graph.dart';
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
        permitsPerceptionEscalation: false,
      );
    }

    final targetEntity = goal.targetEntity;
    if (targetEntity == null) {
      return NavigationDecision.needsMoreEvidence(
        diff,
        'no existe una transición universal para la superficie solicitada',
      );
    }
    final graph = observedCurrent.structuralEvidence;

    // Un overlay modal conserva prioridad sobre los campos que contiene. Un
    // diálogo puede exponer EditText propios (nombre, filtro, contraseña), pero
    // escribir allí el target de conversación sería una mutación fuera de
    // contexto. Primero se cierra mediante evidencia explícita y, si no existe,
    // se usa un único BACK reversible y acotado.
    if (observedCurrent.surfaceKind == CurrentSurfaceKind.dialog) {
      final dismissAction = const ActionSurfaceResolver().resolve(
        graph,
        kind: 'dismiss',
      );
      if (dismissAction != null) {
        return NavigationDecision.act(
          diff: diff,
          action: NavigationAction.tap(dismissAction.selector),
          reason: 'diálogo transitorio; cierre observable y reversible',
        );
      }
      final dialogBack = const ActionSurfaceResolver().resolve(
        graph,
        kind: 'back',
      );
      if (dialogBack != null) {
        return NavigationDecision.act(
          diff: diff,
          action: NavigationAction.tap(dialogBack.selector),
          reason: 'diálogo transitorio; retroceso observable',
        );
      }
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.back(),
        reason: 'diálogo transitorio sin cierre único; retroceso acotado',
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
        permitsPerceptionEscalation: false,
      );
    }

    final searchInput = const InputSurfaceResolver().resolve(
      graph,
      kind: InputSurfaceKind.search,
    );
    if (searchInput != null) {
      if (_sameEntity(searchInput.object.text, targetEntity)) {
        final absence = _explicitNoResults(graph);
        return NavigationDecision.needsMoreEvidence(
          diff,
          absence == null
              ? 'búsqueda ya contiene la entidad pero el resultado no es accionable'
              : 'entidad "$targetEntity" no encontrada; evidencia visible: "$absence"',
          permitsPerceptionEscalation: absence == null,
        );
      }
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.write(searchInput.selector, targetEntity),
        reason: 'campo de búsqueda observado',
      );
    }

    // Una app puede restaurar una actividad interna (estado, perfil, detalle,
    // ajustes) aunque el launch haya sido correcto. Si existe un único control
    // volver/subir observado, úsalo para regresar progresivamente hasta una
    // superficie donde aparezca la entidad o la búsqueda. NavigationHistory
    // mantiene el presupuesto y evita ciclos; aquí se decide una sola acción.
    final backAction = const ActionSurfaceResolver().resolve(
      graph,
      kind: 'back',
    );
    if (backAction != null) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.tap(backAction.selector),
        reason: 'superficie interna distinta; navegación atrás observada',
      );
    }

    final dismissAction = const ActionSurfaceResolver().resolve(
      graph,
      kind: 'dismiss',
    );
    if (dismissAction != null) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.tap(dismissAction.selector),
        reason: 'superficie transitoria; cierre observable y reversible',
      );
    }

    final conversationHome = const ActionSurfaceResolver().resolve(
      graph,
      kind: 'conversations',
    );
    if (conversationHome != null) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.tap(conversationHome.selector),
        reason: 'sección de conversaciones observada y no seleccionada',
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
          object.editable ||
          object.isEditableRole ||
          _belongsToEditable(current, object) ||
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
    // Una misma entidad puede aparecer a la vez en el buscador y en la fila
    // de resultados. El buscador es evidencia del query, no un destino de
    // navegación. Además, varios hijos semánticos de una misma fila deben
    // representar UNA acción y no una ambigüedad artificial.
    final selectorsByTapTarget = <String, String>{};
    for (final object in graph.objects) {
      if (!object.visible ||
          object.editable ||
          object.isEditableRole ||
          !_objectNamesEntity(object, targetEntity)) {
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
      selectorsByTapTarget.putIfAbsent(target.id, () => selector);
    }
    return List.unmodifiable(selectorsByTapTarget.values);
  }

  String? _entitySelectorFor(NanoUiObject object, String targetEntity) {
    if (_sameEntity(object.text, targetEntity)) {
      return _groundedEntitySelector(object, 'text', object.text);
    }
    if (_sameEntity(object.description, targetEntity)) {
      return _groundedEntitySelector(object, 'desc', object.description);
    }
    if (_sameEntity(object.label, targetEntity)) {
      return _groundedEntitySelector(object, 'text', object.label);
    }
    return null;
  }

  /// El texto por sí solo también coincide con el query escrito en un
  /// SearchView. El selector compuesto conserva la identidad semántica, limita
  /// el paquete observado y excluye de forma explícita cualquier editable.
  String _groundedEntitySelector(
    NanoUiObject object,
    String identityKey,
    String identityValue,
  ) {
    final parts = <String>[
      if (object.packageName.isNotEmpty) 'pkg=${object.packageName}',
      if (object.resourceId.isNotEmpty) 'id=${object.resourceId}',
      '$identityKey=$identityValue',
      'editable=false',
    ];
    return parts.join(';');
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

  bool _belongsToEditable(CurrentSituation current, NanoUiObject object) {
    var candidate = object;
    for (var depth = 0; depth < 4; depth++) {
      if (candidate.editable || candidate.isEditableRole) return true;
      final parent = current.structuralEvidence.parentOf(candidate.id);
      if (parent == null) return false;
      candidate = parent;
    }
    return candidate.editable || candidate.isEditableRole;
  }

  String? _explicitNoResults(ScreenGraph graph) {
    const messages = {
      'no se encontraron resultados',
      'no se encontró ningún resultado',
      'no hay resultados',
      'sin resultados',
      'no results found',
      'no results',
    };
    for (final object in graph.objects) {
      if (!object.visible) continue;
      for (final raw in [object.text, object.description, object.label]) {
        final normalized = raw
            .trim()
            .replaceAll(RegExp(r'[.!?]+$'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .toLowerCase();
        if (messages.contains(normalized)) return raw.trim();
      }
    }
    return null;
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
