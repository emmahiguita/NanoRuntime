/// Modelos del snapshot nativo; conserva los contratos exportados.
library;

import 'nano_node.dart';
import 'nano_window.dart';
export 'nano_bounds.dart';
export 'nano_node.dart';
export 'nano_window.dart';
export 'nano_atomic_snapshot.dart';

/// Snapshot completo de la ventana activa.
class NanoSnapshot {
  /// packageName del root ("" si null — ventanas OEM pueden no exponerlo).
  final String package;

  /// Nodos en orden pre-order (plano, con [NanoNode.depth]).
  final List<NanoNode> nodes;
  final List<NanoWindow> windows;

  /// Momento de captura (reloj local del dispositivo).
  final DateTime capturedAt;

  /// El recorrido nativo alcanzó al menos uno de sus límites de seguridad.
  final bool truncated;
  final bool nodeLimitReached;
  final bool depthLimitReached;

  NanoSnapshot({
    required this.package,
    required this.nodes,
    this.windows = const [],
    this.truncated = false,
    this.nodeLimitReached = false,
    this.depthLimitReached = false,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  bool get isEmpty => nodes.isEmpty;

  /// Nodos visibles y habilitados (candidatos reales de interacción).
  List<NanoNode> get visibleNodes =>
      nodes.where((n) => n.visible && n.enabled).toList();

  /// Editables visibles en orden de árbol — la posición ordinal alimenta el
  /// criterio "editable + posición" del scoring.
  List<NanoNode> visibleEditables() =>
      visibleNodes.where((n) => n.editable).toList();

  /// Devuelve el propio [node] si recibe taps o su ancestro clicable visible
  /// más cercano. El árbol llega plano en pre-order: al retroceder, cada depth
  /// menor pertenece a la cadena de ancestros hasta alcanzar el root.
  ///
  /// Un selector semántico suele resolver un `TextView` dentro de una fila. El
  /// gesto debe dirigirse a la fila/botón propietario, nunca a un ancestro de
  /// otro subárbol ni a un nodo descubierto por proximidad de coordenadas.
  NanoNode tapTargetFor(NanoNode node) {
    if (node.visible && node.enabled && node.clickable) return node;

    if (node.hasExplicitParent) {
      var parent = node.parentIndex;
      while (parent != null && parent >= 0 && parent < nodes.length) {
        final candidate = nodes[parent];
        if (candidate.windowId != node.windowId) break;
        if (candidate.visible && candidate.enabled && candidate.clickable) {
          return candidate;
        }
        parent = candidate.parentIndex;
      }
      return node;
    }

    var ancestorDepth = node.depth;
    for (
      var cursor = node.index - 1;
      cursor >= 0 && ancestorDepth > 0;
      cursor--
    ) {
      final candidate = nodes[cursor];
      if (candidate.depth >= ancestorDepth) continue;

      ancestorDepth = candidate.depth;
      if (candidate.visible && candidate.enabled && candidate.clickable) {
        return candidate;
      }
    }
    return node;
  }

  /// Parsea `{package, nodes:[…]}` (respuesta de `dumpSnapshot`). Si [raw]
  /// es la lista plana de `dumpScreen`, package queda "" y depth 0.
  factory NanoSnapshot.fromRaw(Map<dynamic, dynamic> raw) {
    final rawNodes = raw['nodes'] as List? ?? const <dynamic>[];
    final rawWindows = raw['windows'] as List? ?? const <dynamic>[];
    final nodes = <NanoNode>[];
    for (var i = 0; i < rawNodes.length; i++) {
      nodes.add(
        NanoNode.fromMap(i, Map<dynamic, dynamic>.from(rawNodes[i] as Map)),
      );
    }
    return NanoSnapshot(
      package: raw['package'] as String? ?? '',
      nodes: nodes,
      windows: [
        for (final window in rawWindows.whereType<Map>())
          NanoWindow.fromMap(window),
      ],
      truncated: raw['truncated'] == true,
      nodeLimitReached: raw['nodeLimitReached'] == true,
      depthLimitReached: raw['depthLimitReached'] == true,
      capturedAt: raw['capturedAtEpochMs'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (raw['capturedAtEpochMs'] as num).toInt(),
            )
          : null,
    );
  }
}
