import 'nano_bounds.dart';

/// Nodo del árbol de accesibilidad (plano, pre-order, con depth).
class NanoNode {
  /// Ordinal global en el snapshot (índice de la lista plana).
  final int index;

  /// Profundidad en el árbol (solo presente en snapshots `dumpSnapshot`).
  /// 0 para dumps planos antiguos sin depth.
  final int depth;
  final String packageName;
  final int windowId;
  final int windowType;
  final int displayId;
  final String rootIdentity;
  final int? parentIndex;
  final int siblingIndex;
  final bool hasExplicitParent;

  /// viewIdResourceName ("" si el nodo no expone id).
  final String id;

  /// className del nodo (ej. `android.widget.Button`).
  final String type;

  final String text;
  final String description;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final bool checkable;
  final bool checked;
  final bool selected;
  final bool focusable;
  final bool focused;
  final bool visible;
  final bool enabled;
  final bool longClickable;
  final bool password;
  final int drawingOrder;
  final String hint;
  final String? rawText;
  final bool showingHint;
  final bool supportsSetText;

  /// Evidencia nativa de vacío; rawText conserva incluso la ayuda publicada como texto.
  final bool emptyEditor;
  final int selectionStart;
  final int selectionEnd;
  final String errorText;
  final bool heading;
  final bool screenReaderFocusable;
  final String paneTitle;
  final String tooltip;
  final String stateDescription;
  final NanoBounds bounds;

  const NanoNode({
    required this.index,
    required this.depth,
    this.packageName = '',
    this.windowId = 0,
    this.windowType = 1,
    this.displayId = 0,
    this.rootIdentity = '',
    this.parentIndex,
    this.siblingIndex = 0,
    this.hasExplicitParent = false,
    required this.id,
    required this.type,
    required this.text,
    required this.description,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    this.checkable = false,
    required this.checked,
    this.selected = false,
    required this.focusable,
    required this.focused,
    required this.visible,
    required this.enabled,
    this.longClickable = false,
    this.password = false,
    this.drawingOrder = 0,
    this.hint = '',
    this.rawText,
    this.showingHint = false,
    this.supportsSetText = false,
    this.emptyEditor = false,
    this.selectionStart = -1,
    this.selectionEnd = -1,
    this.errorText = '',
    this.heading = false,
    this.screenReaderFocusable = false,
    this.paneTitle = '',
    this.tooltip = '',
    this.stateDescription = '',
    required this.bounds,
  });

  bool get hasLabel => text.isNotEmpty || description.isNotEmpty;

  /// Etiqueta legible para reportes: text si no vacío, si no desc, si no type.
  String get label {
    final t = text.trim();
    if (t.isNotEmpty) return t;
    final d = description.trim();
    if (d.isNotEmpty) return d;
    return type;
  }

  /// Parsea un map del canal (`dumpScreen` o `dumpSnapshot`). [index] es el
  /// ordinal asignado por el snapshot.
  factory NanoNode.fromMap(int index, Map<dynamic, dynamic> m) {
    final rawBounds = m['bounds'] as List? ?? const <dynamic>[];
    return NanoNode(
      index: index,
      depth: (m['depth'] as num?)?.toInt() ?? 0,
      packageName: m['package'] as String? ?? '',
      windowId: (m['windowId'] as num?)?.toInt() ?? 0,
      windowType: (m['windowType'] as num?)?.toInt() ?? 1,
      displayId: (m['displayId'] as num?)?.toInt() ?? 0,
      rootIdentity: m['rootIdentity'] as String? ?? '',
      parentIndex: (m['parentIndex'] as num?)?.toInt(),
      siblingIndex: (m['siblingIndex'] as num?)?.toInt() ?? 0,
      hasExplicitParent: m.containsKey('parentIndex'),
      id: m['id'] as String? ?? '',
      type: m['type'] as String? ?? '',
      text: m['text'] as String? ?? '',
      description: m['desc'] as String? ?? '',
      clickable: m['clickable'] == true,
      editable: m['editable'] == true,
      scrollable: m['scrollable'] == true,
      checkable: m['checkable'] == true,
      checked: m['checked'] == true,
      selected: m['selected'] == true,
      focusable: m['focusable'] == true,
      focused: m['focused'] == true,
      visible: m['visible'] == true,
      enabled: m['enabled'] == true,
      longClickable: m['longClickable'] == true,
      password: m['password'] == true,
      drawingOrder: (m['drawingOrder'] as num?)?.toInt() ?? 0,
      hint: m['hint'] as String? ?? '',
      rawText: m['rawText'] as String?,
      showingHint: m['showingHint'] == true,
      supportsSetText: m['supportsSetText'] == true,
      emptyEditor: m['emptyEditor'] == true,
      selectionStart: (m['selectionStart'] as num?)?.toInt() ?? -1,
      selectionEnd: (m['selectionEnd'] as num?)?.toInt() ?? -1,
      errorText: m['error'] as String? ?? '',
      heading: m['heading'] == true,
      screenReaderFocusable: m['screenReaderFocusable'] == true,
      paneTitle: m['paneTitle'] as String? ?? '',
      tooltip: m['tooltip'] as String? ?? '',
      stateDescription: m['stateDescription'] as String? ?? '',
      bounds: rawBounds.length >= 4
          ? NanoBounds.fromList(rawBounds.cast<dynamic>())
          : const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
    );
  }
}
