/// C10 → A12 — NanoObjectMemory V2: memoria contextual VERIFICABLE de UI.
///
/// V2 añade contexto al [UiObjectKey] (screenSignature + semanticTarget) y
/// invalidación por fallos consecutivos, preservando SOUND learning: solo se
/// memoriza éxito verificado; `completedUnverified`/fallo NUNCA entrena éxito.
library;

class UiSelectorEvidence {
  final String? resourceId;
  final String? text;
  final String? desc;
  final String? role;
  final String? near;
  final String? hierarchySignature;

  /// Firma de pantalla donde se VERIFICÓ este selector (contexto, A12).
  final String? screenSignature;

  const UiSelectorEvidence({
    this.resourceId,
    this.text,
    this.desc,
    this.role,
    this.near,
    this.hierarchySignature,
    this.screenSignature,
  });

  String get fingerprint => resourceId ?? text ?? desc ?? role ?? '';

  Map<String, dynamic> toJson() => {
    'resourceId': resourceId,
    'text': text,
    'desc': desc,
    'role': role,
    'near': near,
    'hierarchySignature': hierarchySignature,
    'screenSignature': screenSignature,
  };

  factory UiSelectorEvidence.fromJson(Map<String, dynamic> json) =>
      UiSelectorEvidence(
        resourceId: json['resourceId'] as String?,
        text: json['text'] as String?,
        desc: json['desc'] as String?,
        role: json['role'] as String?,
        near: json['near'] as String?,
        hierarchySignature: json['hierarchySignature'] as String?,
        screenSignature: json['screenSignature'] as String?,
      );
}

class UiObjectKey {
  final String concept;
  final String package;
  final String appVersion;

  /// Firma de pantalla (A12): liga el target al layout/estado de pantalla.
  final String screenSignature;

  /// Target semántico (A12): role esperado (ej. `switchControl`).
  final String semanticTarget;

  const UiObjectKey({
    required this.concept,
    this.package = '',
    this.appVersion = '',
    this.screenSignature = '',
    this.semanticTarget = '',
  });

  Map<String, dynamic> toJson() => {
    'concept': concept,
    'package': package,
    'appVersion': appVersion,
    'screenSignature': screenSignature,
    'semanticTarget': semanticTarget,
  };

  factory UiObjectKey.fromJson(Map<String, dynamic> json) => UiObjectKey(
    concept: json['concept'] as String? ?? '',
    package: json['package'] as String? ?? '',
    appVersion: json['appVersion'] as String? ?? '',
    screenSignature: json['screenSignature'] as String? ?? '',
    semanticTarget: json['semanticTarget'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is UiObjectKey &&
      other.concept == concept &&
      other.package == package &&
      other.appVersion == appVersion &&
      other.screenSignature == screenSignature &&
      other.semanticTarget == semanticTarget;

  @override
  int get hashCode => Object.hash(
    concept,
    package,
    appVersion,
    screenSignature,
    semanticTarget,
  );

  @override
  String toString() =>
      '$concept@$package/$appVersion'
      '${screenSignature.isNotEmpty ? '#$screenSignature' : ''}'
      '${semanticTarget.isNotEmpty ? '[$semanticTarget]' : ''}';
}

class UiObjectEntry {
  final UiObjectKey key;
  final Map<String, UiSelectorEvidence> selectors;
  final int successes;
  final int failures;

  /// Fallos consecutivos (A12): >= umbral invalida el entry hasta nuevo éxito.
  final int consecutiveFailures;

  final DateTime lastVerified;

  const UiObjectEntry({
    required this.key,
    this.selectors = const {},
    this.successes = 0,
    this.failures = 0,
    this.consecutiveFailures = 0,
    required this.lastVerified,
  });

  double get confidence =>
      (successes + failures) == 0 ? 0.0 : successes / (successes + failures);

  UiObjectEntry copyWith({
    String? fingerprint,
    UiSelectorEvidence? selectorOverride,
    Map<String, UiSelectorEvidence>? selectors,
    int? successes,
    int? failures,
    int? consecutiveFailures,
    DateTime? lastVerified,
  }) {
    var sels = selectors ?? this.selectors;
    if (fingerprint != null &&
        fingerprint.isNotEmpty &&
        selectorOverride != null) {
      sels = Map.of(sels)..[fingerprint] = selectorOverride;
    }
    return UiObjectEntry(
      key: key,
      selectors: sels,
      successes: successes ?? this.successes,
      failures: failures ?? this.failures,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key.toJson(),
    'selectors': selectors.values.map((s) => s.toJson()).toList(),
    'successes': successes,
    'failures': failures,
    'consecutiveFailures': consecutiveFailures,
    'lastVerified': lastVerified.toIso8601String(),
  };

  factory UiObjectEntry.fromJson(Map<String, dynamic> json) {
    if (json['key'] is Map) {
      final key = UiObjectKey.fromJson(
        Map<String, dynamic>.from(json['key'] as Map),
      );
      final selectors = <String, UiSelectorEvidence>{};
      for (final raw in (json['selectors'] as List<dynamic>? ?? const [])) {
        final evidence = UiSelectorEvidence.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        if (evidence.fingerprint.isNotEmpty) {
          selectors[evidence.fingerprint] = evidence;
        }
      }
      return UiObjectEntry(
        key: key,
        selectors: selectors,
        successes: (json['successes'] as num?)?.toInt() ?? 0,
        failures: (json['failures'] as num?)?.toInt() ?? 0,
        consecutiveFailures:
            (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
        lastVerified:
            DateTime.tryParse(json['lastVerified'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }

    // Formato legacy (sin anidamiento de key): compat.
    final key = UiObjectKey(
      concept: json['concept'] as String? ?? '',
      package: json['package'] as String? ?? '',
      appVersion: json['appVersion'] as String? ?? '',
    );
    final evidence = UiSelectorEvidence(
      resourceId: json['resourceId'] as String?,
      text: json['text'] as String?,
      desc: json['desc'] as String?,
      role: json['role'] as String?,
      near: json['near'] as String?,
      hierarchySignature: json['hierarchySignature'] as String?,
    );
    return UiObjectEntry(
      key: key,
      selectors: evidence.fingerprint.isEmpty
          ? const {}
          : {evidence.fingerprint: evidence},
      successes: (json['successes'] as num?)?.toInt() ?? 0,
      failures: (json['failures'] as num?)?.toInt() ?? 0,
      lastVerified:
          DateTime.tryParse(json['lastVerified'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class NanoObjectMemory {
  static const double _invalidConfidence = 0.3;

  /// Fallos consecutivos que invalidan un entry (A12).
  static const int _maxConsecutiveFailures = 2;

  final Map<UiObjectKey, UiObjectEntry> _entries;

  const NanoObjectMemory([Map<UiObjectKey, UiObjectEntry> entries = const {}])
    : _entries = entries;

  /// Resuelve el selector verificado para [key]. null si miss, confianza baja o
  /// fallos consecutivos recientes (A12: no actuar sobre memoria stale).
  UiSelectorEvidence? resolve(UiObjectKey key) {
    final entry = _entries[key];
    if (entry == null || entry.confidence < _invalidConfidence) return null;
    if (entry.consecutiveFailures >= _maxConsecutiveFailures) return null;
    if (entry.selectors.isEmpty) return null;
    UiSelectorEvidence? best;
    for (final s in entry.selectors.values) {
      if (s.resourceId != null && s.resourceId!.isNotEmpty) return s;
      best ??= s;
    }
    return best;
  }

  bool isKnown(UiObjectKey key) => _entries[key]?.selectors.isNotEmpty == true;

  /// Confianza con decay temporal (A12): >7 días 0.8, >30 días 0.5.
  double confidence(UiObjectKey key, {DateTime? now}) {
    final entry = _entries[key];
    if (entry == null) return 0.0;
    final t = now ?? DateTime.now();
    final ageDays = t.difference(entry.lastVerified).inDays;
    final decay = ageDays > 30
        ? 0.5
        : ageDays > 7
        ? 0.8
        : 1.0;
    return entry.confidence * decay;
  }

  List<Map<String, dynamic>> toJson() =>
      _entries.values.map((entry) => entry.toJson()).toList();

  factory NanoObjectMemory.fromJson(List<dynamic> raw) {
    final entries = <UiObjectKey, UiObjectEntry>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final entry = UiObjectEntry.fromJson(Map<String, dynamic>.from(item));
      if (entry.key.concept.isEmpty) continue;
      entries[entry.key] = entry;
    }
    return NanoObjectMemory(entries);
  }

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
        consecutiveFailures: 0, // éxito resetea fallos consecutivos
        lastVerified: t,
      ),
    );
  }

  NanoObjectMemory recordFailure(UiObjectKey key, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return _withEntry(
      key,
      (entry) => entry.copyWith(
        failures: entry.failures + 1,
        consecutiveFailures: entry.consecutiveFailures + 1,
        lastVerified: t,
      ),
    );
  }

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
    final entry =
        _entries[key] ?? UiObjectEntry(key: key, lastVerified: DateTime.now());
    return NanoObjectMemory(Map.of(_entries)..[key] = update(entry));
  }
}
