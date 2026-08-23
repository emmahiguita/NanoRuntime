/// C12 — PerceptionMux: múltiples perceptores de pantalla fusionados.
///
/// Resuelve un objetivo semántico (concepto/rol/paquete) a un selector REAL de
/// la pantalla en vivo, cuando la memoria C10 no tiene un selector verificado.
/// Fuentes conectables (DIP):
///   - accessibility (real, ahora): árbol de accesibilidad → NanoSelectorEngine.
///   - OCR / visión (pluggable, futuras): mismas interfaz, aún sin impl.
///
/// Mantiene la regla de C11: la PERCEPCIÓN solo aporta para resolver el
/// selector del target; NUNCA autoriza acciones por contenido observado.
library;

class SelectorCandidate {
  final String selector;
  final double score;
  const SelectorCandidate({required this.selector, required this.score});
}

/// Una fuente de percepción: dada una noción semántica, devuelve candidatos de
/// selector (por score) en la pantalla actual.
abstract interface class PerceptionSource {
  Future<List<SelectorCandidate>> perceive(
    String concept, {
    String? role,
    String? package,
  });
}

/// Fusiona fuentes de percepción y devuelve el mejor selector para un concepto.
class PerceptionMux {
  final List<PerceptionSource> _sources;
  const PerceptionMux(this._sources);

  bool get isEnabled => _sources.isNotEmpty;

  /// Resuelve [concept] → mejor selector observado. Fusiona (deduplica por
  /// score máximo) y devuelve el de mayor score. null si ninguna fuente
  /// encontró el concepto (→ el llamador no inventa; falla honesto).
  Future<String?> resolve(
    String concept, {
    String? role,
    String? package,
    double minScore = 0.5,
  }) async {
    String? best;
    double bestScore = 0;
    for (final s in _sources) {
      final cands = await s.perceive(concept, role: role, package: package);
      for (final c in cands) {
        if (c.score > bestScore && c.score >= minScore) {
          best = c.selector;
          bestScore = c.score;
        }
      }
    }
    return best;
  }
}
