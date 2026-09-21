// virtual_list_accumulator.dart
//
// Acumulador y rastreador de elementos para listas virtualizadas y recicladas en Android.
// - ¿Qué hace?: Conserva elementos vistos durante desplazamientos (scroll) en listas
//   virtualizadas (RecyclerView, ListView, Jetpack Compose LazyColumn).
// - ¿Cómo funciona?: Indexa elementos únicos por clave semántica (texto + descripción),
//   evitando perder items reciclados cuando salen de la ventana visible de accesibilidad.
// - ¿Por qué?: Resuelve el punto 7 de verificación en OPPO ("Mantener el reconocimiento
//   después de desplazarse por una lista") sin saturar la memoria RAM.

library;

import '../semantic/nano_ui_object.dart';
import '../semantic/screen_graph.dart';
import '../semantic/semantic_role.dart';

/// Registro acumulativo de items visibles y reciclados a lo largo de scrolls.
final class VirtualListAccumulator {
  VirtualListAccumulator({this.maxItems = 300});

  final int maxItems;
  final Map<String, NanoUiObject> _accumulated = {};
  int _scrollSteps = 0;

  /// Incorpora los elementos de la pantalla actual pertenecientes a listas o colecciones.
  int ingestSnapshot(ScreenGraph graph) {
    var added = 0;
    for (final obj in graph.objects) {
      if (!obj.visible) continue;
      // Solo items de lista, tarjetas o elementos interactivos de colección
      if (obj.role != SemanticRole.listItem &&
          obj.role != SemanticRole.card &&
          obj.role != SemanticRole.text) {
        continue;
      }

      final key = _computeItemKey(obj);
      if (key.isNotEmpty && !_accumulated.containsKey(key)) {
        if (_accumulated.length >= maxItems) {
          // Desalojo FIFO defensivo para prevenir desbordamientos de RAM
          _accumulated.remove(_accumulated.keys.first);
        }
        _accumulated[key] = obj;
        added++;
      }
    }
    return added;
  }

  /// Registra que se ha realizado un paso de scroll en una dirección.
  void recordScroll() {
    _scrollSteps++;
  }

  /// Busca un elemento acumulado que coincida con [query] de forma insensible a mayúsculas.
  NanoUiObject? findItem(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    for (final entry in _accumulated.entries) {
      if (entry.key.contains(q)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Retorna todos los items únicos acumulados hasta el momento.
  List<NanoUiObject> get allItems => List.unmodifiable(_accumulated.values);

  /// Cantidad de items únicos registrados.
  int get itemCount => _accumulated.length;

  /// Cantidad de pasos de desplazamiento registrados.
  int get scrollSteps => _scrollSteps;

  /// Reinicia el acumulador para una nueva sesión o pantalla distinta.
  void reset() {
    _accumulated.clear();
    _scrollSteps = 0;
  }

  String _computeItemKey(NanoUiObject obj) {
    final text = obj.text.trim().toLowerCase();
    final desc = obj.description.trim().toLowerCase();
    final label = obj.label.trim().toLowerCase();
    if (text.isNotEmpty) return text;
    if (desc.isNotEmpty) return desc;
    if (label.isNotEmpty) return label;
    if (obj.resourceId.isNotEmpty) return '${obj.resourceId}:${obj.bounds.top}';
    return '';
  }
}
