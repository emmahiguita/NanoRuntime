/// Navegador puro orientado al estado objetivo.
library;

import '../memory/verified_transition_memory.dart';
import '../perception/current_situation.dart';
import '../perception/nano_snapshot.dart' show NanoBounds;
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

  NavigationDecision decide(
    CurrentSituation current,
    NavigationGoal goal, {
    VerifiedTransitionMemory? memory,
  }) {
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

    // El hogar de conversaciones visible y NO seleccionado indica que la
    // pantalla actual es otra sección (llamadas, novedades, comunidades):
    // las filas que nombran la entidad allí NO son conversaciones (una fila
    // de llamada abre su detalle, no el chat). Ir a la sección de
    // conversaciones es la transición mínima ANTES de tocar cualquier
    // entidad. En la lista de chats el tab está seleccionado y el resolver
    // no lo devuelve, así que el flujo normal no cambia.
    final conversationHome = const ActionSurfaceResolver().resolve(
      graph,
      kind: 'conversations',
    );
    if (conversationHome != null) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.tap(conversationHome.selector),
        reason: 'sección de conversaciones visible y no seleccionada',
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
    // La entidad está visible pero ningún destino es accionable: en un picker
    // la fila ya pudo quedar seleccionada (re-tocarla alternaría el check) o
    // la pantalla es un perfil/detalle con acciones hacia el contacto.
    if (_entityPresentButNotActionable(observedCurrent, targetEntity)) {
      final confirm = const ActionSurfaceResolver().resolve(
        graph,
        kind: 'confirm',
      );
      if (confirm != null) {
        return NavigationDecision.act(
          diff: diff,
          action: NavigationAction.tap(confirm.selector),
          reason: 'entidad ya seleccionada; confirmación de la selección',
        );
      }
      // Perfil/detalle de contacto: la acción de mensaje abre el chat
      // directamente (icono "Mensaje" del perfil de llamada/contacto).
      final message = const ActionSurfaceResolver().resolve(
        graph,
        kind: 'message',
      );
      if (message != null) {
        return NavigationDecision.act(
          diff: diff,
          action: NavigationAction.tap(message.selector),
          reason: 'acción de mensaje observada hacia el contacto',
        );
      }
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

    // La entidad no está presente: en una colección, un desplazamiento puede
    // revelarla (listas largas, resultados). El ciclo reobserva y el
    // historial limita; el scroll llega antes que retroceder (que puede
    // abandonar la pantalla).
    if (observedCurrent.surfaceKind == CurrentSurfaceKind.collection &&
        !_entityPresentButNotActionable(observedCurrent, targetEntity)) {
      return NavigationDecision.act(
        diff: diff,
        action: NavigationAction.scroll(ScrollDirection.down),
        reason: 'entidad no visible; desplazamiento para revelarla',
      );
    }

    // Una app puede restaurar una actividad interna (perfil, multimedia,
    // ajustes o detalle) donde la sección de conversaciones no está visible.
    // Solo entonces se retrocede progresivamente. NavigationHistory mantiene
    // el presupuesto y evita ciclos; aquí se decide una única acción.
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

    // AUT-MEM-01: la memoria sugiere el ORDEN de recuperación verificado —
    // un hint, nunca prueba. Desde esta superficie, estas acciones llevaron
    // a la superficie objetivo en transiciones verificadas. Cada sugerencia
    // se traduce a una acción grounded actual; el ciclo SIEMPRE reobserva y
    // verifica después.
    final suggestions = memory?.suggest(
          packageName: observedCurrent.packageName,
          fromSurface: observedCurrent.surfaceKind,
          targetSurface: goal.targetSurface,
        ) ??
        const <NavigationActionKind>[];
    for (final actionKind in suggestions) {
      final resolved = _groundedForAction(graph, actionKind, targetEntity);
      if (resolved == null) continue;
      return NavigationDecision.act(
        diff: diff,
        action: resolved,
        reason: 'recuperación sugerida por transiciones verificadas',
      );
    }

    return NavigationDecision.needsMoreEvidence(
      diff,
      'sin acción grounded que reduzca la diferencia',
    );
  }

  /// Traduce una acción sugerida por la memoria a su forma grounded actual.
  /// Los taps a entidades no son sugeribles (requieren ancla observada);
  /// solo navegación estructural con selector grounded.
  NavigationAction? _groundedForAction(
    ScreenGraph graph,
    NavigationActionKind kind,
    String? targetEntity,
  ) {
    switch (kind) {
      case NavigationActionKind.back:
        final backAction = const ActionSurfaceResolver().resolve(
          graph,
          kind: 'back',
        );
        return backAction == null
            ? NavigationAction.back()
            : NavigationAction.tap(backAction.selector);
      case NavigationActionKind.tap:
        // Un tap histórico no es reproducible sin el ancla observada.
        return null;
      case NavigationActionKind.write:
        if (targetEntity == null) return null;
        final input = const InputSurfaceResolver().resolve(
          graph,
          kind: InputSurfaceKind.search,
        );
        return input == null
            ? null
            : NavigationAction.write(input.selector, targetEntity);
      case NavigationActionKind.launchPackage:
        // El paquete objetivo ya lo resuelve el diff antes de llegar aquí.
        return null;
      case NavigationActionKind.scroll:
        return NavigationAction.scroll(ScrollDirection.down);
    }
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
    final tapTargetById = <String, NanoUiObject>{};
    for (final object in graph.objects) {
      if (!object.visible ||
          object.editable ||
          object.isEditableRole ||
          !_objectNamesEntity(object, targetEntity)) {
        continue;
      }
      var target = object;
      for (var depth = 0; depth < 8; depth++) {
        if (target.visible && target.enabled && target.clickable) break;
        final parent = graph.parentOf(target.id);
        if (parent == null) break;
        target = parent;
      }
      if (!target.visible || !target.enabled || !target.clickable) continue;
      // Una fila ya seleccionada en un picker no es un destino nuevo:
      // re-tocarla alternaría el check. La confirmación es otro paso.
      if (_selectedInChain(graph, target)) continue;
      // Conserva el ancla semántica exacta que identificó la entidad. El
      // executor resolverá este nodo en un snapshot fresco y subirá a su
      // ancestro clicable; usar el contenedor aquí degrada a etiquetas
      // genéricas como "android.widget.LinearLayout" y puede tocar otra fila.
      final selector = _entitySelectorFor(object, targetEntity);
      if (selector == null) continue;
      selectorsByTapTarget.putIfAbsent(target.id, () => selector);
      tapTargetById.putIfAbsent(target.id, () => target);
    }
    // Unifica destinos de tap de la MISMA fila física: la foto del contacto
    // ya es clickable y el nombre sube a la fila; la foto está DENTRO de la
    // fila, así que tocar cualquiera es la misma acción. Conservar el
    // contenedor evita declarar ambigua una única fila. El selector
    // conservado es el del ancla que identifica al contenedor completo.
    final finalSelectors = <String, String>{};
    for (final entry in selectorsByTapTarget.entries) {
      final target = tapTargetById[entry.key]!;
      var containerKey = entry.key;
      for (final other in selectorsByTapTarget.entries) {
        if (other.key == entry.key) continue;
        final otherTarget = tapTargetById[other.key]!;
        if (_contains(otherTarget.bounds, target.bounds)) {
          containerKey = other.key;
        }
      }
      final existing = finalSelectors[containerKey];
      if (existing == null ||
          _selectorStrength(entry.value) > _selectorStrength(existing)) {
        finalSelectors[containerKey] = entry.value;
      }
    }
    return List.unmodifiable(finalSelectors.values);
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
      'no se encontraron contactos',
      'no se encontró ningún contacto',
      'no se encontraron chats',
      'no se encontró ningún chat',
      'no se encontraron conversaciones',
      'no se encontró ninguna conversación',
      'nothing found',
      'no matches found',
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

  /// La entidad está observada en el grafo, pero ninguna ancla produjo un
  /// destino accionable no-seleccionado (p. ej. fila ya marcada en un picker).
  bool _entityPresentButNotActionable(
    CurrentSituation current,
    String targetEntity,
  ) {
    for (final object in current.structuralEvidence.objects) {
      if (!object.visible ||
          object.editable ||
          object.isEditableRole ||
          object.evidence.isEmpty ||
          !_objectNamesEntity(object, targetEntity)) {
        continue;
      }
      return true;
    }
    return false;
  }

  bool _selectedInChain(ScreenGraph graph, NanoUiObject object) {
    var current = object;
    for (var depth = 0; depth < 4; depth++) {
      if (current.selected || current.checked) return true;
      final parent = graph.parentOf(current.id);
      if (parent == null) break;
      current = parent;
    }
    if (current.selected || current.checked) return true;
    var frontier = <NanoUiObject>[object];
    final visited = <String>{object.id};
    for (var depth = 0; depth < 2 && frontier.isNotEmpty; depth++) {
      final next = <NanoUiObject>[];
      for (final candidate in frontier) {
        for (final child in graph.childrenOf(candidate.id)) {
          if (!visited.add(child.id)) continue;
          if (child.selected || child.checked) return true;
          next.add(child);
        }
      }
      frontier = next;
    }
    return false;
  }

  /// Especificidad del selector para elegir entre anclas del mismo destino:
  /// la identidad textual exacta es más selectiva que la descripción.
  int _selectorStrength(String selector) {
    if (selector.contains(';text=')) return 3;
    if (selector.contains(';desc=')) return 2;
    if (selector.contains(';id=')) return 1;
    return 0;
  }

  static bool _contains(NanoBounds outer, NanoBounds inner) =>
      outer.left <= inner.left &&
      outer.top <= inner.top &&
      outer.right >= inner.right &&
      outer.bottom >= inner.bottom;
}
