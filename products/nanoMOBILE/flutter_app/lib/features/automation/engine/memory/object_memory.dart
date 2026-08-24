/// C10 — NanoObjectMemory: memoria + identidad VERIFICABLE de elementos UI.
///
/// R0 mantiene el modelo de confianza actual y corrige persistencia:
/// serializar/restaurar conserva evidencia y contadores exactamente.
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

  String get fingerprint => resourceId ?? text ?? desc ?? role ?? '';

  Map<String, dynamic> toJson() => {
    'resourceId': resourceId,
    'text': text,
    'desc': desc,
    'role': role,
    'near': near,
    'hierarchySignature': hierarchySignature,
  };

  factory UiSelectorEvidence.fromJson(Map<String, dynamic> json) =>
      UiSelectorEvidence(
        resourceId: json['resourceId'] as String?,
        text: json['text'] as String?,
        desc: json['desc'] as String?,
        role: json['role'] as String?,
        near: json['near'] as String?,
        hierarchySignature: json['hierarchySignature'] as String?,
      );
}

class UiObjectKey {
  final String concept;
  final String package;
  final String appVersion;

  const UiObjectKey({
    required this.concept,
    this.package = '',
    this.appVersion = '',
  });

  Map<String, dynamic> toJson() => {
    'concept': concept,
    'package': package,
    'appVersion': appVersion,
  };

  factory UiObjectKey.fromJson(Map<String, dynamic> json) => UiObjectKey(
    concept: json['concept'] as String? ?? '',
    package: json['package'] as String? ?? '',
    appVersion: json['appVersion'] as String? ?? '',
  );

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

  double get confidence =>
      (successes + failures) == 0 ? 0.0 : successes / (successes + failures);

  UiObjectEntry copyWith({
    String? fingerprint,
    UiSelectorEvidence? selectorOverride,
    Map<String, UiSelectorEvidence>? selectors,
    int? successes,
    int? failures,
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
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key.toJson(),
    'selectors': selectors.values.map((s) => s.toJson()).toList(),
    'successes': successes,
    'failures': failures,
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
        lastVerified:
            DateTime.tryParse(json['lastVerified'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }

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
  final Map<UiObjectKey, UiObjectEntry> _entries;

  const NanoObjectMemory([Map<UiObjectKey, UiObjectEntry> entries = const {}])
    : _entries = entries;

  UiSelectorEvidence? resolve(UiObjectKey key) {
    final entry = _entries[key];
    if (entry == null || entry.confidence < _invalidConfidence) return null;
    if (entry.selectors.isEmpty) return null;
    UiSelectorEvidence? best;
    for (final s in entry.selectors.values) {
      if (s.resourceId != null && s.resourceId!.isNotEmpty) return s;
      best ??= s;
    }
    return best;
  }

  bool isKnown(UiObjectKey key) => _entries[key]?.selectors.isNotEmpty == true;

  double confidence(UiObjectKey key) => _entries[key]?.confidence ?? 0.0;

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
        lastVerified: t,
      ),
    );
  }

  NanoObjectMemory recordFailure(UiObjectKey key, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return _withEntry(
      key,
      (entry) => entry.copyWith(failures: entry.failures + 1, lastVerified: t),
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
