/// SearchResultResolver (T2.9-select) — resuelve resultados de búsqueda REALES
/// desde el ScreenGraph/Accessibility y produce un selector GROUNDED para
/// seleccionarlos. 0 LLM para ordinales; matching textual determinista.
///
/// "abre el segundo resultado" → ordinal=2 → ScreenGraph.results[1] → selector.
/// "abre el resultado que dice X" → matching textual → candidato o clarificación.
///
/// La resolución física queda aquí (ScreenGraph/Accessibility), nunca en el
/// TaskOrchestrator (que solo pide `selectResult(ordinal/text)` semántico).
library;

import 'nano_snapshot.dart' show NanoBounds;
import 'semantic/nano_ui_object.dart';
import 'semantic/screen_graph.dart';
import 'semantic/semantic_role.dart';

/// Proveniencia del candidato. OCR entra SOLO si accessibility/screenGraph no
/// aportan (escalado de la PerceptionMux, no un motor paralelo).
enum SearchResultSource { accessibility, screenGraph, ocr }

/// Resultado de búsqueda observado con evidencia real (title/subtitle/resourceId).
class SearchResultCandidate {
  /// 1-based (primero=1, segundo=2, ...).
  final int ordinal;
  final String title;
  final String subtitle;
  final String resourceId;
  final NanoBounds bounds;

  /// Package de la app origen; se enriquece desde NanoSnapshot.package en el
  /// composition root (ScreenGraph no lo expone). '' = sin enriquecer.
  final String packageName;
  final double confidence;
  final SearchResultSource source;

  /// Selector grounded para re-encontrar el nodo en el ejecutor (id/text/desc).
  final String selector;

  const SearchResultCandidate({
    required this.ordinal,
    required this.title,
    required this.subtitle,
    required this.resourceId,
    required this.bounds,
    required this.packageName,
    required this.confidence,
    required this.source,
    required this.selector,
  });
}

/// Objetivo de selección: por ordinal o por texto. Semántico, nunca coordenadas.
sealed class ResultTarget {
  const ResultTarget();
}

class ResultOrdinal extends ResultTarget {
  final int ordinal;
  const ResultOrdinal(this.ordinal);
}

class ResultText extends ResultTarget {
  final String text;
  const ResultText(this.text);
}

/// Veredicto de resolución: resuelto, ambiguo (clarificar) o no encontrado.
sealed class ResultResolution {
  const ResultResolution();
}

class ResultResolved extends ResultResolution {
  final SearchResultCandidate candidate;
  const ResultResolved(this.candidate);
}

class ResultAmbiguous extends ResultResolution {
  final List<SearchResultCandidate> candidates;
  const ResultAmbiguous(this.candidates);
}

class ResultNotFound extends ResultResolution {
  const ResultNotFound();
}

class ResultIncompleteEvidence extends ResultResolution {
  final List<SearchResultCandidate> observed;
  const ResultIncompleteEvidence(this.observed);
}

class SearchResultResolver {
  const SearchResultResolver();

  /// Roles que pueden ser un resultado táctil (no campo, no toolbar, no switch).
  static const _resultRoles = {
    SemanticRole.listItem,
    SemanticRole.card,
    SemanticRole.link,
    SemanticRole.button,
    SemanticRole.text,
    SemanticRole.image,
  };

  /// Extrae los resultados observados, ordenados top→bottom, con ordinal 1-based.
  /// Solo nodos visibles, clickeables, no-editables, con selector grounded.
  List<SearchResultCandidate> resolveResults(ScreenGraph graph) {
    final objects = graph.objects;
    final searchBottom = _searchFieldBottom(objects);

    final partials = <NanoUiObject>[];
    for (final o in objects) {
      if (!o.visible || !o.clickable || o.editable) continue;
      if (!_resultRoles.contains(o.role)) continue;
      if (_selectorFor(o) == null) continue;
      // Un resultado está debajo del campo de búsqueda (si hay campo visible).
      if (searchBottom != null && o.bounds.top < searchBottom) continue;
      partials.add(o);
    }
    partials.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    return [
      for (var i = 0; i < partials.length; i++) _candidate(partials[i], i + 1),
    ];
  }

  ResultResolution resolve(ScreenGraph graph, ResultTarget target) {
    final results = resolveResults(graph);
    if (graph.truncated) return ResultIncompleteEvidence(results);
    return switch (target) {
      ResultOrdinal(:final ordinal) => _resolveOrdinal(results, ordinal),
      ResultText(:final text) => _resolveText(results, text),
    };
  }

  ResultResolution _resolveOrdinal(
    List<SearchResultCandidate> results,
    int ordinal,
  ) {
    final idx = ordinal - 1;
    if (idx < 0 || idx >= results.length) return const ResultNotFound();
    return ResultResolved(results[idx]);
  }

  ResultResolution _resolveText(
    List<SearchResultCandidate> results,
    String text,
  ) {
    final needle = text.trim().toLowerCase();
    if (needle.isEmpty) return const ResultNotFound();
    final matches = results
        .where(
          (r) =>
              r.title.toLowerCase().contains(needle) ||
              r.subtitle.toLowerCase().contains(needle),
        )
        .toList(growable: false);
    if (matches.isEmpty) return const ResultNotFound();
    // Dos o más coinciden: clarificación, NUNCA tap a ciegas.
    if (matches.length > 1) return ResultAmbiguous(matches);
    return ResultResolved(matches.first);
  }

  /// Borde inferior del campo de búsqueda visible (ancla superior de resultados).
  double? _searchFieldBottom(List<NanoUiObject> objects) {
    double? bottom;
    for (final o in objects) {
      if (o.editable && o.visible) {
        final b = o.bounds.bottom.toDouble();
        if (bottom == null || b < bottom) bottom = b;
      }
    }
    return bottom;
  }

  String? _selectorFor(NanoUiObject o) {
    if (o.resourceId.isNotEmpty) return 'id=${o.resourceId}';
    if (o.text.isNotEmpty) return 'text=${o.text}';
    if (o.description.isNotEmpty) return 'desc=${o.description}';
    return null;
  }

  SearchResultCandidate _candidate(NanoUiObject o, int ordinal) {
    final title = o.text.isNotEmpty
        ? o.text
        : (o.description.isNotEmpty ? o.description : o.label);
    final subtitle = (o.description.isNotEmpty && o.description != title)
        ? o.description
        : '';
    return SearchResultCandidate(
      ordinal: ordinal,
      title: title,
      subtitle: subtitle,
      resourceId: o.resourceId,
      bounds: o.bounds,
      packageName: '',
      confidence: 0.8,
      source: SearchResultSource.accessibility,
      selector: _selectorFor(o)!,
    );
  }
}
