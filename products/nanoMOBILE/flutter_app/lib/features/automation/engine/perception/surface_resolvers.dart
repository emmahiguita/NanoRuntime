/// T2.0 — SurfaceResolvers: resuelven superficies UI REALES (input editable y
/// botón de acción) desde el ScreenGraph, devolviendo un selector grounded.
///
/// Sustituyen el patrón roto de escribir en un selector vacío (`write('', text)`)
/// y de tocar un `desc=Enviar` hardcodeado. Direct-first, 0 LLM: el objeto sale
/// de la OBSERVACIÓN real de la pantalla (Accessibility → ScreenGraph), nunca de
/// un string inventado por el modelo.
///
/// Puro Dart: dependen solo del modelo semántico (ScreenGraph/NanoUiObject).
/// El snapshot/IO lo hace el llamador (composition root).
library;

import 'semantic/nano_ui_object.dart';
import 'semantic/screen_graph.dart';
import 'surface_profiles.dart';

/// Superficie UI grounded: el objeto observado + el selector para re-encontrarlo
/// en el ejecutor + el motivo que la hizo ganar (diagnóstico honesto).
class ResolvedSurface {
  final NanoUiObject object;
  final String selector;
  final String reason;

  const ResolvedSurface(this.object, this.selector, this.reason);
}

/// Intención de la superficie editable. `any` queda para los consumidores
/// genéricos; las acciones mutantes deben pedir una superficie específica.
enum InputSurfaceKind { any, message, search }

/// Selector más grounded posible para un objeto: resourceId > text > desc >
/// flag estructural. El resourceId es el más estable; `editable=true` es el
/// último recurso (puede ser ambiguo, pero nunca inventa un id/text).
String surfaceSelectorFor(NanoUiObject o) {
  if (o.resourceId.isNotEmpty) return 'id=${o.resourceId}';
  if (o.text.isNotEmpty) return 'text=${o.text}';
  if (o.description.isNotEmpty) return 'desc=${o.description}';
  if (o.label.isNotEmpty) return 'text=${o.label}';
  return 'editable=true';
}

/// Encuentra un nodo editable REAL para escribir (composer, buscador, campo).
///
/// La intención de la operación filtra los campos antes de priorizarlos: una
/// búsqueda no puede escribir en el compositor, ni un mensaje en el buscador.
/// Solo `any` admite el fallback a cualquier editable visible.
class InputSurfaceResolver {
  const InputSurfaceResolver({
    SurfaceProfileSource profiles = const SurfaceProfileRegistry(),
  }) : _profiles = profiles;

  final SurfaceProfileSource _profiles;

  ResolvedSurface? resolve(
    ScreenGraph graph, {
    InputSurfaceKind kind = InputSurfaceKind.any,
  }) {
    // Un snapshot truncado invalida una conclusión negativa, pero no una
    // superficie positiva ya observada y anclada. Los árboles profundos pueden
    // superar el límite en una rama irrelevante mientras el input buscado sí
    // está presente. El ejecutor volverá a resolver el
    // selector sobre un snapshot fresco y exigirá unicidad/actionability.
    final editables = graph.objects
        .where((o) => o.visible && o.editable)
        .toList(growable: false);
    if (editables.isEmpty) return null;

    final profiles = _profiles.resolve(graph.package, _elementKindFor(kind));
    for (final profile in profiles) {
      final candidates = editables
          .where((o) => _matchesKind(o, kind, profile))
          .toList(growable: false);
      if (candidates.isEmpty) continue;

      for (final o in candidates) {
        if (o.focused) {
          return ResolvedSurface(
            o,
            surfaceSelectorFor(o),
            'focused editable (${profile.sourceProfileId})',
          );
        }
      }
      for (final o in candidates) {
        if (profile.matchesRole(o.role)) {
          return ResolvedSurface(
            o,
            surfaceSelectorFor(o),
            '${o.role.name} role (${profile.sourceProfileId})',
          );
        }
      }
      final o = candidates.first;
      return ResolvedSurface(
        o,
        surfaceSelectorFor(o),
        'matching editable (${profile.sourceProfileId})',
      );
    }

    // Campos sin identidad accesible (YouTube: EditText sin resource-id ni
    // hint expuesto). Tras el tap del icono de búsqueda (transición explícita
    // del llamador), el ÚNICO editable visible y enfocado ES el buscador.
    if (kind == InputSurfaceKind.search &&
        editables.length == 1 &&
        editables.single.focused) {
      final o = editables.single;
      return ResolvedSurface(
        o,
        surfaceSelectorFor(o),
        'único campo enfocado (búsqueda)',
      );
    }
    return null;
  }

  bool _matchesKind(
    NanoUiObject object,
    InputSurfaceKind kind,
    ResolvedSurfaceProfile profile,
  ) {
    if (kind == InputSurfaceKind.any) return true;

    // El texto visible puede estar vacío (por ejemplo, una caja web) o
    // contener la URL actual. La identidad accesible estable vive entonces en
    // resourceId/nativeClass; omitirla deja al agente sin un destino grounded
    // aun cuando Android sí expone el campo correcto.
    final hay =
        '${object.text} ${object.description} ${object.label} '
                '${object.resourceId} ${object.nativeClass}'
            .toLowerCase();
    return profile.matchesRole(object.role) || profile.matchesTerms(hay);
  }

  SurfaceElementKind _elementKindFor(InputSurfaceKind kind) => switch (kind) {
    InputSurfaceKind.any => SurfaceElementKind.anyInput,
    InputSurfaceKind.message => SurfaceElementKind.messageInput,
    InputSurfaceKind.search => SurfaceElementKind.searchInput,
  };
}

/// Resuelve una entidad nombrada a una acción UI observada y única. Prioriza
/// igualdad semántica; solo usa coincidencia parcial cuando produce un único
/// destino clicable. Nunca usa coordenadas ni selecciona `first` ante empate.
class EntityActionSurfaceResolver {
  const EntityActionSurfaceResolver();

  List<ResolvedSurface> resolve(ScreenGraph graph, String entity) {
    final key = _normalize(entity);
    if (key.isEmpty || key.contains(';')) return const [];

    final eligible = graph.objects
        .where(
          (object) =>
              object.visible &&
              object.enabled &&
              !object.editable &&
              !object.isEditableRole,
        )
        .toList(growable: false);
    var anchors = eligible
        .where((object) => _labels(object).any((value) => value == key))
        .toList(growable: false);
    var exact = true;
    if (anchors.isEmpty) {
      exact = false;
      anchors = eligible
          .where(
            (object) => _labels(object).any((value) => value.contains(key)),
          )
          .toList(growable: false);
    }

    final byTapTarget = <String, ResolvedSurface>{};
    for (final anchor in anchors) {
      var tapTarget = anchor;
      for (var depth = 0; depth < 4; depth++) {
        if (tapTarget.visible && tapTarget.enabled && tapTarget.clickable) {
          break;
        }
        final parent = graph.parentOf(tapTarget.id);
        if (parent == null) break;
        tapTarget = parent;
      }
      if (!tapTarget.visible || !tapTarget.enabled || !tapTarget.clickable) {
        continue;
      }
      final selector = _semanticSelector(anchor, key);
      if (selector == null) continue;
      byTapTarget.putIfAbsent(
        tapTarget.id,
        () => ResolvedSurface(
          anchor,
          selector,
          exact ? 'exact visible action' : 'unique partial visible action',
        ),
      );
    }
    return List.unmodifiable(byTapTarget.values);
  }

  Iterable<String> _labels(NanoUiObject object) sync* {
    for (final value in [object.text, object.description, object.label]) {
      final normalized = _normalize(value);
      if (normalized.isNotEmpty) yield normalized;
    }
  }

  String? _semanticSelector(NanoUiObject object, String entityKey) {
    final identities = <(String, String)>[
      ('text', object.text),
      ('desc', object.description),
      ('text', object.label),
    ];
    for (final identity in identities) {
      final value = identity.$2.trim();
      if (value.isEmpty || value.contains(';')) continue;
      final normalized = _normalize(value);
      if (normalized != entityKey && !normalized.contains(entityKey)) continue;
      return <String>[
        if (object.packageName.isNotEmpty) 'pkg=${object.packageName}',
        if (object.resourceId.isNotEmpty) 'id=${object.resourceId}',
        '${identity.$1}=$value',
        'editable=false',
      ].join(';');
    }
    return null;
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Resuelve un campo editable por la identidad pronunciada por el usuario.
/// Devuelve todos los destinos grounded para que el caller exija unicidad.
/// Si el campo carece de id/description estable, solo se usa `editable=true`
/// cuando es el único editable visible; así el selector sobrevive al reemplazo
/// del placeholder por el valor escrito.
class EntityInputSurfaceResolver {
  const EntityInputSurfaceResolver();

  List<ResolvedSurface> resolve(
    ScreenGraph graph,
    String entity, {
    String packageName = '',
  }) {
    final key = _normalize(entity);
    if (key.isEmpty || key.contains(';')) return const [];
    final editables = _editables(graph, packageName);
    if (editables.isEmpty) return const [];

    var candidates = editables
        .where((object) => _identities(object).any((value) => value == key))
        .toList(growable: false);
    var exact = true;
    if (candidates.isEmpty) {
      exact = false;
      candidates = editables
          .where(
            (object) => _identities(object).any((value) => value.contains(key)),
          )
          .toList(growable: false);
    }

    final resolved = <ResolvedSurface>[];
    for (final object in candidates) {
      final selector = _stableSelector(
        object,
        onlyEditable: editables.length == 1,
      );
      if (selector == null) continue;
      resolved.add(
        ResolvedSurface(
          object,
          selector,
          exact ? 'exact named input' : 'partial named input',
        ),
      );
    }
    return List.unmodifiable(resolved);
  }

  /// Fallback permitido solo tras una transición explícita y observada. Nunca
  /// elige `first`: exactamente un editable visible o ningún resultado.
  List<ResolvedSurface> resolveSoleEditable(
    ScreenGraph graph, {
    String packageName = '',
  }) {
    final editables = _editables(graph, packageName);
    if (editables.length != 1) return const [];
    final object = editables.single;
    final selector = _stableSelector(object, onlyEditable: true);
    if (selector == null) return const [];
    return [
      ResolvedSurface(object, selector, 'sole editable after transition'),
    ];
  }

  List<NanoUiObject> _editables(ScreenGraph graph, String packageName) {
    final expectedPackage = packageName.trim().toLowerCase();
    return graph.objects
        .where(
          (object) =>
              object.visible &&
              object.enabled &&
              object.editable &&
              (expectedPackage.isEmpty ||
                  object.packageName.trim().toLowerCase() == expectedPackage),
        )
        .toList(growable: false);
  }

  Iterable<String> _identities(NanoUiObject object) sync* {
    for (final value in [
      object.text,
      object.description,
      object.label,
      object.resourceId.replaceAll(RegExp(r'[_./:-]+'), ' '),
    ]) {
      final normalized = _normalize(value);
      if (normalized.isNotEmpty) yield normalized;
    }
  }

  String? _stableSelector(NanoUiObject object, {required bool onlyEditable}) {
    final parts = <String>[
      if (object.packageName.isNotEmpty) 'pkg=${object.packageName}',
    ];
    if (object.resourceId.isNotEmpty && !object.resourceId.contains(';')) {
      parts.add('id=${object.resourceId}');
    } else if (onlyEditable) {
      // `editable=true` sigue apuntando al único campo aunque el placeholder
      // desaparezca después de ACTION_SET_TEXT.
    } else if (object.description.isNotEmpty &&
        !object.description.contains(';')) {
      parts.add('desc=${object.description}');
    } else {
      return null;
    }
    parts.add('editable=true');
    return parts.join(';');
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Encuentra el botón de ACCIÓN semántica (enviar/buscar/ir) asociado al input
/// activo. Sustituye `tap('desc=Enviar')`: el botón se identifica por rol
/// (button/iconButton) + términos semánticos, y se prefiere el más cercano al
/// input activo (relación de posición con el compositor).
class ActionSurfaceResolver {
  const ActionSurfaceResolver({
    SurfaceProfileSource profiles = const SurfaceProfileRegistry(),
  }) : _profiles = profiles;

  final SurfaceProfileSource _profiles;

  ResolvedSurface? resolve(ScreenGraph graph, {String kind = 'send'}) {
    // Igual que en InputSurfaceResolver: la truncación impide afirmar
    // ausencia, no descarta evidencia positiva ya observada. La acción final
    // conserva re-resolución, estabilidad y actionability en el executor.
    final elementKind = switch (kind) {
      'send' => SurfaceElementKind.sendAction,
      'search' => SurfaceElementKind.searchAction,
      'back' => SurfaceElementKind.navigationBackAction,
      'dismiss' => SurfaceElementKind.navigationDismissAction,
      'overflow' => SurfaceElementKind.navigationOverflowAction,
      'conversations' => SurfaceElementKind.conversationHomeAction,
      'confirm' => SurfaceElementKind.confirmAction,
      'message' => SurfaceElementKind.messageAction,
      'skipAd' => SurfaceElementKind.skipAdAction,
      _ => null,
    };
    if (elementKind == null) return null;
    final profiles = _profiles.resolve(graph.package, elementKind);
    for (final profile in profiles) {
      final buttons = graph.objects
          .where((o) {
            if (!o.visible || !o.enabled) return false;
            // Un snapshot puede contener ventanas de la app, teclado, sistema
            // y overlays. Una acción de navegación solo puede pertenecer al
            // paquete activo; de lo contrario un "Atrás" o "Chats" externo
            // puede secuestrar la decisión aunque la pantalla principal sea
            // WhatsApp. Los nodos sin package se conservan porque algunos
            // servicios OEM omiten ese atributo en hijos del árbol activo.
            final graphPackage = graph.package.trim().toLowerCase();
            final objectPackage = o.packageName.trim().toLowerCase();
            if (graphPackage.isNotEmpty &&
                objectPackage.isNotEmpty &&
                objectPackage != graphPackage) {
              return false;
            }
            final matchesRole = profile.matchesRole(o.role);
            if (!matchesRole &&
                !(profile.allowClickableContainer && o.clickable)) {
              return false;
            }
            final hay = '${o.label} ${o.text} ${o.description} ${o.resourceId}'
                .toLowerCase();
            if (kind == 'back' ||
                kind == 'dismiss' ||
                kind == 'overflow' ||
                kind == 'conversations' ||
                kind == 'confirm' ||
                kind == 'message' ||
                kind == 'skipAd') {
              if (_selectedInChain(graph, o)) return false;
              return _matchesExactNavigationAction(o, profile, kind);
            }
            return profile.matchesTerms(hay);
          })
          .toList(growable: false);
      if (buttons.isEmpty) continue;

      final navigationAction =
          kind == 'back' ||
          kind == 'dismiss' ||
          kind == 'overflow' ||
          kind == 'conversations' ||
          kind == 'confirm' ||
          kind == 'message' ||
          kind == 'skipAd';
      final candidates = navigationAction
          ? _uniqueNavigationAnchors(graph, buttons)
          : buttons;

      // Android puede exponer la misma pestaña como contenedor clicable y
      // como texto hijo. La unicidad pertenece al destino de tap real, no al
      // número de nodos semánticos que lo describen. Si quedan dos destinos
      // clicables distintos, se mantiene el fail-closed.
      if (candidates.isEmpty || (navigationAction && candidates.length != 1)) {
        continue;
      }

      var best = candidates.first;
      var reason = 'action button ($kind, ${profile.sourceProfileId})';
      final input = InputSurfaceResolver(profiles: _profiles).resolve(
        graph,
        kind: kind == 'search'
            ? InputSurfaceKind.search
            : InputSurfaceKind.message,
      );
      if (input != null) {
        var bestDist = double.infinity;
        for (final b in candidates) {
          final d = b.bounds.distanceTo(input.object.bounds).toDouble();
          if (d < bestDist) {
            bestDist = d;
            best = b;
          }
        }
        reason = 'action button ($kind, ${profile.sourceProfileId}) near input';
      }
      final selector = navigationAction
          ? _navigationSelector(graph, best)
          : surfaceSelectorFor(best);
      if (selector == null) continue;
      return ResolvedSurface(best, selector, reason);
    }
    return null;
  }

  bool _matchesExactNavigationAction(
    NanoUiObject object,
    ResolvedSurfaceProfile profile,
    String kind,
  ) {
    for (final value in [object.label, object.text, object.description]) {
      for (final candidate in _navigationEvidenceVariants(value)) {
        if (profile.matchesExactTerm(candidate)) return true;
      }
    }
    final resource = object.resourceId.toLowerCase().split('/').last;
    return switch (kind) {
      'back' => const {
        'back',
        'back_button',
        'toolbar_back',
        'navigation_back',
        'navigate_up',
        'action_bar_up',
        'up',
      }.contains(resource),
      'dismiss' => const {
        'close',
        'close_button',
        'dismiss',
        'cancel',
        'cancel_button',
      }.contains(resource),
      'overflow' => const {
        'menu',
        'menu_button',
        'menuitem_overflow',
        'overflow',
        'overflow_menu',
        'more_options',
        'action_overflow',
      }.contains(resource),
      'confirm' => const {
        'next',
        'next_button',
        'confirm',
        'confirm_button',
        'done',
        'btn_next',
        'button_next',
      }.contains(resource),
      'message' => const {
        'message',
        'message_button',
        'chat',
        'send_message',
        'btn_message',
      }.contains(resource),
      'skipAd' => const {
        'skip_ad',
        'skipad',
        'skip_ad_button',
        'ad_skip',
        'skip',
      }.contains(resource),
      _ => false,
    };
  }

  /// Conserva matching exacto aunque Android decore una pestaña con su badge:
  /// `Chats, 9 notificaciones` sigue identificando la pestaña `Chats`. No usa
  /// contains arbitrario: únicamente admite la etiqueta completa o su primer
  /// segmento accesible antes de metadatos/badges.
  Iterable<String> _navigationEvidenceVariants(String value) sync* {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    if (normalized.isEmpty) return;
    yield normalized;

    final firstSegment = normalized.split(RegExp(r'[,;|•·]')).first.trim();
    if (firstSegment.isNotEmpty && firstSegment != normalized) {
      yield firstSegment;
    }

    final withoutBadge = normalized
        .replaceFirst(
          RegExp(
            r'\s+\d+\s*(?:notificaciones?|notifications?|mensajes?|messages?|sin leer|unread)?\s*$',
          ),
          '',
        )
        .trim();
    if (withoutBadge.isNotEmpty && withoutBadge != normalized) {
      yield withoutBadge;
    }
  }

  List<NanoUiObject> _uniqueNavigationAnchors(
    ScreenGraph graph,
    List<NanoUiObject> anchors,
  ) {
    final byTapTarget = <String, NanoUiObject>{};
    for (final anchor in anchors) {
      final tapTarget = _tapTarget(graph, anchor);
      if (tapTarget == null) continue;
      final existing = byTapTarget[tapTarget.id];
      if (existing == null ||
          _selectorStrength(anchor) > _selectorStrength(existing)) {
        byTapTarget[tapTarget.id] = anchor;
      }
    }
    return List.unmodifiable(byTapTarget.values);
  }

  NanoUiObject? _tapTarget(ScreenGraph graph, NanoUiObject anchor) {
    var current = anchor;
    for (var depth = 0; depth < 5; depth++) {
      if (current.visible && current.enabled && current.clickable) {
        return current;
      }
      final parent = graph.parentOf(current.id);
      if (parent == null) return null;
      current = parent;
    }
    return null;
  }

  int _selectorStrength(NanoUiObject object) {
    if (object.resourceId.isNotEmpty) return 4;
    if (object.description.isNotEmpty) return 3;
    if (object.text.isNotEmpty) return 2;
    if (object.label.isNotEmpty) return 1;
    return 0;
  }

  String? _navigationSelector(ScreenGraph graph, NanoUiObject object) {
    final parts = <String>[
      if (object.packageName.isNotEmpty) 'pkg=${object.packageName}',
    ];

    // WhatsApp y otras apps reutilizan el mismo resourceId en cada item de
    // una barra inferior. Un selector `id=...` en ese caso convierte `Chats`
    // y `Comunidades` en candidatos idénticos. El id solo es canónico cuando
    // la observación actual demuestra que es único.
    final resourceId = object.resourceId.trim();
    final uniqueResource =
        resourceId.isNotEmpty &&
        !resourceId.contains(';') &&
        graph.objects.where((candidate) {
              return candidate.visible &&
                  candidate.enabled &&
                  candidate.resourceId == resourceId;
            }).length ==
            1;
    if (uniqueResource) {
      parts.add('id=$resourceId');
    } else {
      final identities = <(String, String)>[
        ('desc', object.description),
        ('text', object.text),
        ('text', object.label),
      ];
      for (final identity in identities) {
        final value = identity.$2.trim();
        if (value.isEmpty || value.contains(';')) continue;
        parts.add('${identity.$1}=$value');
        break;
      }
    }
    if (parts.length == (object.packageName.isEmpty ? 0 : 1)) return null;
    return parts.join(';');
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

    // Android no es uniforme al exponer el estado de una pestaña: algunos
    // layouts marcan el contenedor y otros únicamente un hijo (texto/icono).
    // Revisar la rama evita volver a tocar `Chats` cuando ya está seleccionada,
    // lo que produciría una transición sin cambio y agotaría el presupuesto.
    var frontier = <NanoUiObject>[object];
    final visited = <String>{object.id};
    for (var depth = 0; depth < 4 && frontier.isNotEmpty; depth++) {
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
}
