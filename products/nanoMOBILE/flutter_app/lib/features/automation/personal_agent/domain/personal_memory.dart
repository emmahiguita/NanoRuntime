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
  final int id;
  final String scopeKey, key, value, kind;
  final int observedAt;
  final Map<String, String> metadata;
  bool get enabled => metadata['enabled'] != 'false';
  int? get expiresAt => int.tryParse(metadata['expiresAt'] ?? '');
  bool get expired =>
      expiresAt != null && expiresAt! <= DateTime.now().millisecondsSinceEpoch;
  String get importBatch => metadata['importBatch'] ?? '';
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
