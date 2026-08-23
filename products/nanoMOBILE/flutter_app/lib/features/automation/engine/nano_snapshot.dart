/// Modelos inmutables del árbol de accesibilidad (snapshot).
///
/// Capa pura: sin MethodChannel. Los mapas vienen del canal `com.nanoai/agent`
/// (método `dumpSnapshot` en Kotlin) y aquí se convierten a tipos seguros para
/// el Selector Engine y el Actionability Engine.
library;

/// Bounds en coordenadas absolutas de pantalla (px).
class NanoBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const NanoBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int get width => right - left;
  int get height => bottom - top;
  int get centerX => (left + right) ~/ 2;
  int get centerY => (top + bottom) ~/ 2;

  /// Gap en px entre este rect y [other]: 0 si se solapan en ambos ejes.
  /// Para el criterio "near" se mide por eje (ver [xOverlapRatio]).
  int distanceTo(NanoBounds other) {
    final xGap = (other.left > right)
        ? other.left - right
        : (left > other.right)
            ? left - other.right
            : 0;
    final yGap = (other.top > bottom)
        ? other.top - bottom
        : (top > other.bottom)
            ? top - other.bottom
            : 0;
    return xGap > yGap ? xGap : yGap;
  }

  /// Fracción de solapamiento en el eje X (0..1) respecto a [other].
  /// Patrón label→campo: el TextView y el EditText comparten casi todo el
  /// ancho de la fila.
  double xOverlapRatio(NanoBounds other) {
    final overlapStart = left > other.left ? left : other.left;
    final overlapEnd = right < other.right ? right : other.right;
    final overlap = overlapEnd - overlapStart;
    if (overlap <= 0) return 0;
    final mine = width;
    final theirs = other.width;
    final minWidth = mine < theirs ? mine : theirs;
    if (minWidth <= 0) return 0;
    return overlap / minWidth;
  }

  /// [l, t, r, b] — el formato que envía el canal nativo.
  factory NanoBounds.fromList(List<dynamic> l) {
    return NanoBounds(
      left: (l[0] as num).toInt(),
      top: (l[1] as num).toInt(),
      right: (l[2] as num).toInt(),
      bottom: (l[3] as num).toInt(),
    );
  }

  @override
  String toString() => '[$left,$top,$right,$bottom]';
}

/// Nodo del árbol de accesibilidad (plano, pre-order, con depth).
class NanoNode {
  /// Ordinal global en el snapshot (índice de la lista plana).
  final int index;

  /// Profundidad en el árbol (solo presente en snapshots `dumpSnapshot`).
  /// 0 para dumps planos antiguos sin depth.
  final int depth;

  /// viewIdResourceName ("" si el nodo no expone id).
  final String id;

  /// className del nodo (ej. `android.widget.Button`).
  final String type;

  final String text;
  final String description;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final bool checked;
  final bool focusable;
  final bool focused;
  final bool visible;
  final bool enabled;
  final NanoBounds bounds;

  const NanoNode({
    required this.index,
    required this.depth,
    required this.id,
    required this.type,
    required this.text,
    required this.description,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.checked,
    required this.focusable,
    required this.focused,
    required this.visible,
    required this.enabled,
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
      id: m['id'] as String? ?? '',
      type: m['type'] as String? ?? '',
      text: m['text'] as String? ?? '',
      description: m['desc'] as String? ?? '',
      clickable: m['clickable'] == true,
      editable: m['editable'] == true,
      scrollable: m['scrollable'] == true,
      checked: m['checked'] == true,
      focusable: m['focusable'] == true,
      focused: m['focused'] == true,
      visible: m['visible'] == true,
      enabled: m['enabled'] == true,
      bounds: rawBounds.length >= 4
          ? NanoBounds.fromList(rawBounds.cast<dynamic>())
          : const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
    );
  }
}

/// Snapshot completo de la ventana activa.
class NanoSnapshot {
  /// packageName del root ("" si null — ventanas OEM pueden no exponerlo).
  final String package;

  /// Nodos en orden pre-order (plano, con [NanoNode.depth]).
  final List<NanoNode> nodes;

  /// Momento de captura (reloj local del dispositivo).
  final DateTime capturedAt;

  NanoSnapshot({
    required this.package,
    required this.nodes,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  bool get isEmpty => nodes.isEmpty;

  /// Nodos visibles y habilitados (candidatos reales de interacción).
  List<NanoNode> get visibleNodes =>
      nodes.where((n) => n.visible && n.enabled).toList();

  /// Editables visibles en orden de árbol — la posición ordinal alimenta el
  /// criterio "editable + posición" del scoring.
  List<NanoNode> visibleEditables() => visibleNodes
      .where((n) => n.editable)
      .toList();

  /// Parsea `{package, nodes:[…]}` (respuesta de `dumpSnapshot`). Si [raw]
  /// es la lista plana de `dumpScreen`, package queda "" y depth 0.
  factory NanoSnapshot.fromRaw(Map<dynamic, dynamic> raw) {
    final rawNodes = raw['nodes'] as List? ?? const <dynamic>[];
    final nodes = <NanoNode>[];
    for (var i = 0; i < rawNodes.length; i++) {
      nodes.add(NanoNode.fromMap(i, Map<dynamic, dynamic>.from(rawNodes[i] as Map)));
    }
    return NanoSnapshot(
      package: raw['package'] as String? ?? '',
      nodes: nodes,
    );
  }
}
