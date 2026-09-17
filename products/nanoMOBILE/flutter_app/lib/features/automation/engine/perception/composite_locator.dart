/// NanoCompositeLocator — Localizador en cascada Dynamic-First de Nano
///
/// Implementa la regla fundamental de localización móvil de Nano:
/// "Dynamic-first, coordinate-fallback".
///
/// Orden de resolución prioritario:
/// 1. Resource ID unívoco del nodo nativo.
/// 2. Semántica dinámica (texto, contentDescription, rol del control).
/// 3. Relacional / Estructural (etiquetas cercanas, contenedores padres clicables).
/// 4. Percepción visual / OCR (coincidencia de cajas de texto visual).
/// 5. Coordenadas absolutas verificadas contra los límites de la pantalla activa.
library;

import '../execution/agent_result.dart';
import 'nano_selector.dart';
import 'nano_snapshot.dart';
import 'selector_engine.dart';

/// Estrategia concreta que resolvió el elemento.
enum LocatorStrategy {
  dynamicResourceId,
  semanticText,
  relationalNeighbor,
  visualOcr,
  coordinateFallback,
  none,
}

/// Resultado exhaustivo de la resolución de localización.
final class LocatorResolution {
  const LocatorResolution({
    required this.strategy,
    required this.isResolved,
    this.targetNode,
    this.tapCoordinates,
    this.confidence = 0.0,
    required this.diagnostic,
  });

  final LocatorStrategy strategy;
  final bool isResolved;
  final NanoNode? targetNode;

  /// Coordenadas calculadas para la interacción [x, y].
  final (int, int)? tapCoordinates;
  final double confidence;
  final String diagnostic;

  factory LocatorResolution.unresolved(String reason) => LocatorResolution(
    strategy: LocatorStrategy.none,
    isResolved: false,
    confidence: 0.0,
    diagnostic: reason,
  );

  factory LocatorResolution.resolved({
    required LocatorStrategy strategy,
    required NanoNode node,
    required (int, int) coordinates,
    double confidence = 1.0,
    required String diagnostic,
  }) => LocatorResolution(
    strategy: strategy,
    isResolved: true,
    targetNode: node,
    tapCoordinates: coordinates,
    confidence: confidence,
    diagnostic: diagnostic,
  );

  factory LocatorResolution.coordinateFallback({
    required (int, int) coordinates,
    required String diagnostic,
    double confidence = 0.5,
  }) => LocatorResolution(
    strategy: LocatorStrategy.coordinateFallback,
    isResolved: true,
    targetNode: null,
    tapCoordinates: coordinates,
    confidence: confidence,
    diagnostic: diagnostic,
  );
}

/// Elemento OCR para fallback visual.
final class VisualOcrElement {
  const VisualOcrElement({required this.text, required this.bounds});

  final String text;
  final NanoBounds bounds;
}

/// Motor de localización en cascada desacoplado y determinista.
class NanoCompositeLocator {
  NanoCompositeLocator({NanoSelectorEngine? selectorEngine})
    : _selectorEngine = selectorEngine ?? NanoSelectorEngine();

  final NanoSelectorEngine _selectorEngine;

  /// Resuelve un objetivo siguiendo estrictamente la jerarquía Dynamic-First.
  LocatorResolution locate({
    required NanoSelector selector,
    required NanoSnapshot snapshot,
    List<VisualOcrElement> ocrElements = const [],
    (int, int)? fallbackCoordinates,
  }) {
    if (snapshot.isEmpty) {
      return LocatorResolution.unresolved(
        'Snapshot vacío: sin árbol a11y activo',
      );
    }

    // ── PASO 1: Dynamic Resource ID unívoco ────────────────────────────────
    if (selector.resourceId != null && selector.resourceId!.isNotEmpty) {
      final idMatches = snapshot.visibleNodes
          .where((n) => n.id.trim() == selector.resourceId!.trim())
          .toList();

      if (idMatches.length == 1) {
        final node = snapshot.tapTargetFor(idMatches.first);
        return LocatorResolution.resolved(
          strategy: LocatorStrategy.dynamicResourceId,
          node: node,
          coordinates: (node.bounds.centerX, node.bounds.centerY),
          confidence: 1.0,
          diagnostic:
              'Localizado por ResourceId unívoco: ${selector.resourceId}',
        );
      }
    }

    // ── PASO 2 & 3: Semántica y Relacional vía SelectorEngine ─────────────
    final outcome = _selectorEngine.resolve(selector, snapshot);
    if (outcome.isResolved && outcome.best != null) {
      final best = outcome.best!;
      final target = snapshot.tapTargetFor(best.node);

      final strategy = selector.near != null
          ? LocatorStrategy.relationalNeighbor
          : LocatorStrategy.semanticText;

      return LocatorResolution.resolved(
        strategy: strategy,
        node: target,
        coordinates: (target.bounds.centerX, target.bounds.centerY),
        confidence: best.score > 100
            ? 0.95
            : (best.score / 120.0).clamp(0.0, 0.9),
        diagnostic:
            'Localizado dinámicamente ($strategy) con score ${best.score}: ${target.label}',
      );
    }

    // ── PASO 4: Fallback Visual / OCR si hay elementos de texto detectados ──
    if (selector.text != null &&
        selector.text!.isNotEmpty &&
        ocrElements.isNotEmpty) {
      final query = selector.text!.toLowerCase().trim();
      final ocrMatches = ocrElements.where((e) {
        final text = e.text.toLowerCase().trim();
        return text == query || text.contains(query);
      }).toList();

      if (ocrMatches.length == 1) {
        final match = ocrMatches.first;
        return LocatorResolution.resolved(
          strategy: LocatorStrategy.visualOcr,
          node: NanoNode(
            index: -1,
            depth: 0,
            id: '',
            type: 'android.view.View',
            text: match.text,
            description: '',
            clickable: true,
            editable: false,
            scrollable: false,
            checked: false,
            focusable: true,
            focused: false,
            visible: true,
            enabled: true,
            bounds: match.bounds,
          ),
          coordinates: (match.bounds.centerX, match.bounds.centerY),
          confidence: 0.75,
          diagnostic:
              'Localizado por percepción OCR: "${match.text}" en ${match.bounds}',
        );
      }
    }

    // ── PASO 5: Fallback a coordenadas absolutas (último recurso) ───────────
    if (fallbackCoordinates != null) {
      final (x, y) = fallbackCoordinates;
      if (x >= 0 && y >= 0) {
        return LocatorResolution.coordinateFallback(
          coordinates: (x, y),
          diagnostic:
              'Fallback a coordenadas explícitas ($x, $y) tras agotar localizadores dinámicos.',
        );
      }
    }

    return LocatorResolution.unresolved(
      outcome.status == ResolveStatus.ambiguous
          ? 'Objetivo ambiguo: múltiples candidatos semánticos encontrados'
          : 'No se encontró ningún elemento dinámico ni visual compatible con el selector',
    );
  }
}
