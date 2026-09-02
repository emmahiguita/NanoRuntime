/// SemanticNormalizer (A7) — Accessibility → NanoUiObject[].
///
/// Puro, determinista, sin IO/LLM/plataforma. Mismo snapshot → mismo resultado.
/// Reconstruye la jerarquía (parentId) del pre-order + depth, clasifica el rol
/// por señales fuertes (clase/flags) antes que heurística estructural.
library;

import '../nano_snapshot.dart' show NanoNode, NanoSnapshot;
import 'nano_ui_object.dart';
import 'semantic_role.dart';

class SemanticNormalizer {
  const SemanticNormalizer();

  List<NanoUiObject> normalize(NanoSnapshot snapshot) {
    final nodes = snapshot.nodes;
    if (nodes.isEmpty) return const [];

    final objects = <NanoUiObject>[];
    final stack = <int>[]; // índices de nodos (reconstruye parent del depth)
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      while (stack.isNotEmpty && nodes[stack.last].depth >= node.depth) {
        stack.removeLast();
      }
      final parentIndex = node.hasExplicitParent
          ? node.parentIndex
          : (stack.isEmpty ? null : stack.last);
      final hasChildren =
          i + 1 < nodes.length && nodes[i + 1].depth > node.depth;
      objects.add(_classify(node, parentIndex, hasChildren));
      stack.add(i);
    }
    return _refineListItems(objects);
  }

  NanoUiObject _classify(NanoNode n, int? parentIndex, bool hasChildren) {
    final cls = n.type.toLowerCase();
    final role = _roleFor(n, cls, hasChildren);
    return NanoUiObject(
      id: 'ui:${n.index}',
      role: role,
      label: n.label,
      text: n.text,
      description: n.description,
      bounds: n.bounds,
      enabled: n.enabled,
      visible: n.visible,
      clickable: n.clickable,
      editable: n.editable,
      scrollable: n.scrollable,
      checked: n.checked,
      selected: n.selected,
      focusable: n.focusable,
      focused: n.focused,
      nativeClass: n.type,
      resourceId: n.id,
      parentId: parentIndex == null ? null : 'ui:$parentIndex',
      confidence: _confidenceFor(n, cls, role),
      evidence: _evidenceFor(n, cls, role),
      sourceIndex: n.index,
      packageName: n.packageName,
      windowId: n.windowId,
      windowType: n.windowType,
      displayId: n.displayId,
      rootIdentity: n.rootIdentity,
      siblingIndex: n.siblingIndex,
    );
  }

  SemanticRole _roleFor(NanoNode n, String cls, bool hasChildren) {
    // 1. editable → textField (con especializaciones search/password).
    if (n.editable) {
      if (_isPassword(n)) return SemanticRole.passwordField;
      if (_isSearch(n)) return SemanticRole.searchField;
      return SemanticRole.textField;
    }
    // 2. señales fuertes por clase.
    if (_hasClass(cls, [
      'switch',
      'togglebutton',
      'switchcompat',
      'materialswitch',
    ])) {
      return SemanticRole.switchControl;
    }
    if (cls.contains('checkbox')) return SemanticRole.checkbox;
    if (cls.contains('radiobutton')) return SemanticRole.radio;
    if (_hasClass(cls, ['seekbar', 'slider'])) return SemanticRole.slider;
    if (cls.contains('imagebutton')) return SemanticRole.iconButton;
    if (cls.contains('imageview')) return SemanticRole.image;
    if (cls.contains('button')) {
      return _isIconButton(n) ? SemanticRole.iconButton : SemanticRole.button;
    }
    if (_hasClass(cls, ['recyclerview', 'listview'])) {
      return SemanticRole.list;
    }
    if (cls.contains('gridview')) return SemanticRole.grid;
    if (_isToolbar(n, cls, hasChildren)) return SemanticRole.toolbar;
    if (cls.contains('webview')) return SemanticRole.unknown; // contenedor web
    // 3. heurística estructural.
    if (n.clickable && hasChildren) return SemanticRole.card;
    if (n.clickable && n.hasLabel) return SemanticRole.button;
    // 4. texto.
    if (cls.contains('textview') || n.hasLabel) return SemanticRole.text;
    return SemanticRole.unknown;
  }

  double _confidenceFor(NanoNode n, String cls, SemanticRole role) {
    switch (role) {
      case SemanticRole.textField:
        return cls.contains('edittext') ? 0.99 : 0.95;
      case SemanticRole.searchField:
        return 0.90;
      case SemanticRole.passwordField:
        return 0.75; // heurística secundaria: el snapshot no expone `password`
      case SemanticRole.switchControl:
      case SemanticRole.checkbox:
      case SemanticRole.radio:
      case SemanticRole.slider:
      case SemanticRole.button:
        return 0.99;
      case SemanticRole.iconButton:
        return cls.contains('imagebutton') || cls.contains('button')
            ? 0.99
            : 0.85;
      case SemanticRole.image:
      case SemanticRole.list:
        return 0.95;
      case SemanticRole.toolbar:
        return 0.90;
      case SemanticRole.card:
        return 0.70;
      case SemanticRole.text:
        return cls.contains('textview') ? 0.95 : 0.90;
      default:
        return 0.5;
    }
  }

  List<SemanticEvidenceSource> _evidenceFor(
    NanoNode n,
    String cls,
    SemanticRole role,
  ) {
    switch (role) {
      case SemanticRole.textField:
        return cls.contains('edittext')
            ? const [
                SemanticEvidenceSource.accessibilityFlag,
                SemanticEvidenceSource.accessibilityClass,
              ]
            : const [SemanticEvidenceSource.accessibilityFlag];
      case SemanticRole.searchField:
      case SemanticRole.passwordField:
        return const [
          SemanticEvidenceSource.accessibilityFlag,
          SemanticEvidenceSource.textHeuristic,
        ];
      case SemanticRole.switchControl:
      case SemanticRole.checkbox:
      case SemanticRole.radio:
      case SemanticRole.slider:
      case SemanticRole.button:
      case SemanticRole.iconButton:
      case SemanticRole.image:
      case SemanticRole.list:
        return const [SemanticEvidenceSource.accessibilityClass];
      case SemanticRole.toolbar:
        return cls.contains('toolbar')
            ? const [SemanticEvidenceSource.accessibilityClass]
            : const [SemanticEvidenceSource.resourceId];
      case SemanticRole.card:
        return const [SemanticEvidenceSource.structure];
      case SemanticRole.text:
        return cls.contains('textview')
            ? const [SemanticEvidenceSource.accessibilityClass]
            : const [SemanticEvidenceSource.textHeuristic];
      default:
        return const [];
    }
  }

  /// Hijo de un `list`/`grid` con rol estructural → `listItem`.
  List<NanoUiObject> _refineListItems(List<NanoUiObject> objects) {
    final byId = {for (final o in objects) o.id: o};
    return [
      for (final o in objects)
        if (o.parentId != null &&
            (byId[o.parentId]?.role == SemanticRole.list ||
                byId[o.parentId]?.role == SemanticRole.grid) &&
            (o.role == SemanticRole.unknown ||
                o.role == SemanticRole.card ||
                o.role == SemanticRole.text))
          o.copyWith(
            role: SemanticRole.listItem,
            confidence: 0.80,
            evidence: [...o.evidence, SemanticEvidenceSource.structure],
          )
        else
          o,
    ];
  }

  bool _hasClass(String cls, List<String> terms) => terms.any(cls.contains);

  bool _isToolbar(NanoNode n, String cls, bool hasChildren) {
    if (cls.contains('toolbar')) return true;
    if (!hasChildren) return false;
    final resourceName = n.id.toLowerCase().split('/').last;
    return resourceName == 'toolbar';
  }

  bool _isSearch(NanoNode n) {
    final hay = '${n.id} ${n.text} ${n.description}'.toLowerCase();
    return _containsAny(hay, [
      'search',
      'buscar',
      'busqueda',
      'búsqueda',
      'query',
      'src_text',
      // Superficies de navegación web: el omnibox también es un campo de
      // búsqueda válido. Se reconoce por semántica de recurso, no por package
      // ni por coordenadas, de modo que sirve aunque el navegador restaure
      // cualquier página o actividad previa.
      'url_bar',
      'address_bar',
      'location_bar',
      'omnibox',
    ]);
  }

  bool _isPassword(NanoNode n) {
    final hay = '${n.id} ${n.description}'.toLowerCase();
    return _containsAny(hay, [
      'password',
      'contraseña',
      'contrasena',
      'passwd',
      'pwd',
      'clave',
    ]);
  }

  bool _isIconButton(NanoNode n) =>
      n.description.isNotEmpty && n.text.trim().isEmpty;

  bool _containsAny(String hay, List<String> terms) => terms.any(hay.contains);
}
