import 'dart:convert';
import 'package:crypto/crypto.dart';

String personalizationScope(String conversationId) => conversationId.isEmpty
    ? 'owner'
    : 'contact:${sha256.convert(utf8.encode(conversationId))}';

const personalMemoryKinds = {
  'stablePreference': 'Preferencia estable',
  'stableRelationshipFact': 'Relación estable',
  'businessFact': 'Dato de negocio por verificar',
  'episodicMemory': 'Recuerdo histórico',
  'temporaryFact': 'Dato temporal',
  'stylePreference': 'Preferencia de estilo',
};

/// Estado de vigencia semántica de un recuerdo o hecho (Ciclos 10 y 17).
enum MemoryLifecycleState { current, superseded, historical }

final class PersonalMemory {
  const PersonalMemory({
    this.id = -1,
    required this.scopeKey,
    required this.key,
    required this.value,
    required this.kind,
    required this.observedAt,
    this.metadata = const {},
  });

  /// TTL conservador por defecto (8 horas) para estados temporales sin expiresAt explícito.
  static const int defaultCurrentStateTtlMs = 8 * 60 * 60 * 1000;

  final int id;
  final String scopeKey, key, value, kind;
  final int observedAt;
  final Map<String, String> metadata;

  bool get enabled => metadata['enabled'] != 'false';
  double get confidence => double.tryParse(metadata['confidence'] ?? '') ?? 0.7;
  bool get hasReliableTimestamp => observedAt > 0;
  int? get expiresAt => int.tryParse(metadata['expiresAt'] ?? '');

  bool get isTemporalKind =>
      kind == 'temporaryFact' ||
      kind == 'liveObservedState' ||
      kind == 'explicitCurrentState';

  /// Un estado temporal expira por su `expiresAt` explícito o tras 8h desde `observedAt`.
  bool isTemporalExpired([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (!hasReliableTimestamp || observedAt > now) return true;
    if (expiresAt != null) return expiresAt! <= now;
    if (isTemporalKind) {
      return (now - observedAt) > defaultCurrentStateTtlMs;
    }
    return false;
  }

  /// Para observaciones transitorias (`pendingObservation`), `expired` indica borrado;
  /// para estados personales temporales (`temporaryFact`), `isTemporalExpired` degrada a histórico.
  bool get expired =>
      expiresAt != null && expiresAt! <= DateTime.now().millisecondsSinceEpoch;

  /// Ciclo 10 + 17: determina si el recuerdo es vigente (`current`), reemplazado (`superseded`) o `historical`.
  MemoryLifecycleState lifecycleAt([int? nowMs]) {
    if (metadata['lifecycle'] == 'superseded') {
      return MemoryLifecycleState.superseded;
    }
    if (!hasReliableTimestamp ||
        kind == 'episodicMemory' ||
        isTemporalExpired(nowMs)) {
      return MemoryLifecycleState.historical;
    }
    return MemoryLifecycleState.current;
  }

  /// Regla Ciclo 10: expired CurrentState -> HistoricalEvent/context != current evidence.
  String effectiveKind([int? nowMs]) {
    final state = lifecycleAt(nowMs);
    if (state != MemoryLifecycleState.current &&
        (isTemporalKind ||
            kind == 'stablePreference' ||
            kind == 'stableRelationshipFact')) {
      return 'episodicMemory';
    }
    return kind;
  }

  String get importBatch => metadata['importBatch'] ?? '';

  /// Ciclo 17: Resuelve contradicciones y supersession entre memorias del mismo sujeto/clave.
  /// Ejemplo: "Trabajo en empresa A" -> "Ya no trabajo ahí; ahora estoy en B"
  /// o "Me gusta X" -> "Ya no me gusta X".
  static List<PersonalMemory> resolveSupersession(List<PersonalMemory> items) {
    if (items.length <= 1) return items;
    final sorted = [...items]
      ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    final seenActiveByKey = <String, PersonalMemory>{};
    final result = <PersonalMemory>[];

    for (final item in sorted) {
      final normKey = item.key.trim().toLowerCase();
      final newer = seenActiveByKey[normKey];
      if (newer != null && _supersedes(newer, item)) {
        result.add(
          item.copyWith(
            metadata: {
              ...item.metadata,
              'lifecycle': 'superseded',
              'supersededBy': '${newer.id}',
            },
          ),
        );
      } else {
        if (normKey.isNotEmpty) {
          seenActiveByKey.putIfAbsent(normKey, () => item);
        }
        result.add(item);
      }
    }
    return result;
  }

  static bool _supersedes(PersonalMemory newer, PersonalMemory older) {
    if (newer.observedAt <= older.observedAt) return false;
    final normNew = newer.value.toLowerCase();
    final normOld = older.value.toLowerCase();
    if (normNew == normOld) return true;
    const retractionSignals = [
      'ya no ',
      'ahora estoy en ',
      'ahora trabajo en ',
      'cambie de ',
      'cambié de ',
      'deje de ',
      'dejé de ',
      'no me gusta ',
      'antes ',
    ];
    if (retractionSignals.any(normNew.contains)) return true;
    return newer.key.trim().toLowerCase() == older.key.trim().toLowerCase() &&
        (older.kind == 'stablePreference' ||
            older.kind == 'stableRelationshipFact' ||
            older.kind == 'temporaryFact');
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'scopeKey': scopeKey,
    'key': key,
    'value': value,
    'kind': kind,
    'observedAt': observedAt,
    'metadata': metadata,
  };

  factory PersonalMemory.fromRow(Map<dynamic, dynamic> row) {
    final raw = row['metadata'];
    final decoded = raw is String ? jsonDecode(raw) : raw;
    return PersonalMemory(
      id: (row['id'] as num?)?.toInt() ?? -1,
      scopeKey: row['scopeKey'] as String? ?? 'owner',
      key: row['key'] as String? ?? '',
      value: row['value'] as String? ?? '',
      kind: row['kind'] as String? ?? 'episodicMemory',
      observedAt: (row['observedAt'] as num?)?.toInt() ?? 0,
      metadata: decoded is Map
          ? decoded.map((k, v) => MapEntry('$k', '$v'))
          : const {},
    );
  }

  PersonalMemory copyWith({
    String? key,
    String? value,
    String? kind,
    int? observedAt,
    Map<String, String>? metadata,
  }) => PersonalMemory(
    id: id,
    scopeKey: scopeKey,
    key: key ?? this.key,
    value: value ?? this.value,
    kind: kind ?? this.kind,
    observedAt: observedAt ?? this.observedAt,
    metadata: metadata ?? this.metadata,
  );
}
