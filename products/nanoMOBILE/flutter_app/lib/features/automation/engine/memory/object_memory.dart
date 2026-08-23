/// C10 — NanoObjectMemory: memoria + identidad VERIFICABLE de elementos UI.
///
/// Propósito: que el planner pequeño NO tenga que inventar selectores
/// (`id=resourceId`). Guarda, por identidad de objeto (concepto + paquete +
/// versión de app), evidencia de selectores VERIFICADOS + estadísticas de
/// acierto/fallo + confianza. La resolución devuelve SOLO selectores con
/// confianza suficiente; si no → null (el llamador falla honesto, NUNCA
/// devuelve "parecido≠éxito").
///
/// Regla crítica (RESOLUTION adapta, VERIFICATION estricta): este objeto solo
/// MEMORIZA lo que el GoalVerifier confirmó; nunca marca éxito por similitud.
library;

class UiSelectorEvidence {
  final String? resourceId;
  final String? text;
  final String? desc;
  final String? role;
  final String? near;
  final String? hierarchySignature;

  const UiSelectorEvidence({
    this.resourceId,
    this.text,
    this.desc,
    this.role,
    this.near,
    this.hierarchySignature,
  });

  /// Clave para deduplicar selectores en un mismo objeto.
  String get fingerprint => resourceId ?? text ?? desc ?? role ?? '';

  Map<String, dynamic> toJson() => {
        'resourceId': resourceId,
        'text': text,
        'desc': desc,
        'role': role,
        'near': near,
        'hierarchySignature': hierarchySignature,
      };
}

/// Identidad semántica+contextual de un objeto UI.
class UiObjectKey {
  final String concept;
  final String package;
  final String appVersion;

  const UiObjectKey({
    required this.concept,
    this.package = '',
    this.appVersion = '',
  });

  @override
  bool operator ==(Object other) =>
      other is UiObjectKey &&
      other.concept == concept &&
      other.package == package &&
      other.appVersion == appVersion;

  @override
  int get hashCode => Object.hash(concept, package, appVersion);

  @override
  String toString() => '$concept@$package/$appVersion';
}

class UiObjectEntry {
  final UiObjectKey key;
  final Map<String, UiSelectorEvidence> selectors;
  final int successes;
  final int failures;
  final DateTime lastVerified;

  const UiObjectEntry({
    required this.key,
    this.selectors = const {},
    this.successes = 0,
    this.failures = 0,
    required this.lastVerified,
  });

  /// Confianza = aciertos / (aciertos + fallos). 0 si aún sin datos.
  double get confidence => (successes + failures) == 0
      ? 0.0
      : successes / (successes + failures);

  UiObjectEntry copyWith({
    String? fingerprint,
    UiSelectorEvidence? selectorOverride,
    Map<String, UiSelectorEvidence>? selectors,
    int? successes,
    int? failures,
    DateTime? lastVerified,
  }) {
    var sels = selectors ?? this.selectors;
    if (fingerprint != null && selectorOverride != null) {
      sels = Map.of(sels)..[fingerprint] = selectorOverride;
    }
    return UiObjectEntry(
      key: key,
      selectors: sels,
      successes: successes ?? this.successes,
      failures: failures ?? this.failures,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }
}

/// Memoria de objetos UI verificados (bounded por entrada, inmutable en
/// updates → thread-safe, copy-on-write).
class NanoObjectMemory {
  static const double _invalidConfidence = 0.3;
  final Map<UiObjectKey, UiObjectEntry> _entries;

  const NanoObjectMemory([Map<UiObjectKey, UiObjectEntry> entries = const {}])
      : _entries = entries;

  /// Mejor selector VERIFICADO para [key] (confianza suficiente). Prefiere
  /// resourceId (más estable). null = sin evidencia fiable → no inventar.
  UiSelectorEvidence? resolve(UiObjectKey key) {
    final entry = _entries[key];
    if (entry == null || entry.confidence < _invalidConfidence) return null;
    if (entry.selectors.isEmpty) return null;
    UiSelectorEvidence? best;
    for (final s in entry.selectors.values) {
      if (s.resourceId != null) return s; // resourceId es el más robusto
      best ??= s;
    }
    return best;
  }

  bool isKnown(UiObjectKey key) => _entries[key]?.selectors.isNotEmpty == true;

  double confidence(UiObjectKey key) => _entries[key]?.confidence ?? 0.0;

  /// Serializa las entradas (mejor selector por objeto) para persistencia (C13).
  List<Map<String, dynamic>> toJson() {
    final out = <Map<String, dynamic>>[];
    for (final e in _entries.values) {
      UiSelectorEvidence? best;
      for (final s in e.selectors.values) {
        if (s.resourceId != null) {
          best = s;
          break; // resourceId es el más robusto
        }
        best ??= s;
      }
      out.add({
        'concept': e.key.concept,
        'package': e.key.package,
        'appVersion': e.key.appVersion,
        'resourceId': best?.resourceId,
        'text': best?.text,
        'successes': e.successes,
        'failures': e.failures,
      });
    }
    return out;
  }

  /// Acierto VERIFICADO: sube confianza + fija el selector como evidencia.
  NanoObjectMemory recordSuccess(
    UiObjectKey key,
    UiSelectorEvidence selector, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    return _withEntry(
      key,
      (entry) => entry.copyWith(
        fingerprint: selector.fingerprint,
        selectorOverride: selector,
        successes: entry.successes + 1,
        lastVerified: t,
      ),
    );
  }

  /// Fallo REAL: baja confianza. Al cruzar el umbral, [resolve] dejará de
  /// devolver el selector (se rediscovery semántico aguas arriba).
  NanoObjectMemory recordFailure(UiObjectKey key, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return _withEntry(
      key,
      (entry) => entry.copyWith(
        failures: entry.failures + 1,
        lastVerified: t,
      ),
    );
  }

  /// Invalida explícitamente (se olvida el selector) tras fallos repetidos.
  NanoObjectMemory invalidate(UiObjectKey key) {
    final e = _entries[key];
    if (e == null) return this;
    return NanoObjectMemory(
      Map.of(_entries)..[key] = e.copyWith(selectors: const {}),
    );
  }

  NanoObjectMemory _withEntry(
    UiObjectKey key,
    UiObjectEntry Function(UiObjectEntry) update,
  ) {
    final entry = _entries[key] ??
        UiObjectEntry(key: key, lastVerified: DateTime.now());
    return NanoObjectMemory(Map.of(_entries)..[key] = update(entry));
  }
}
