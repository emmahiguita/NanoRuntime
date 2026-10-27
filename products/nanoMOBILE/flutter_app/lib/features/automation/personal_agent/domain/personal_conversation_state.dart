/// LOOP-3-STATE-V2 — estado personal compacto por conversación.
///
/// Consolida en UNA estructura serializable lo que el modelo necesita para
/// responder sin releer la conversación completa: tema actual, intención
/// reciente, referencia sin resolver y compromisos abiertos. Se persiste
/// como UNA fila `personalTurnState` de [PersonalMemory] por conversación
/// (datastore existente, jamás un store paralelo) y hereda su lifecycle
/// current/superseded/historical + TTL.
///
/// Compacto por contrato: tamaños acotados, nunca transcripciones.
library;

/// Compromiso o promesa pendiente dentro de la conversación
/// (LOOP 4 — concepto explícito: creación por detector determinista,
/// nunca una inferencia incierta convertida en hecho).
final class OpenLoopSummary {
  final String id;
  final String description;

  /// 'pending_commitment' | 'reminder' | 'generic'
  final String type;

  /// Quién contrajo el compromiso: 'contact' (él prometió) | 'owner'
  /// (Nano prometió en nombre del dueño) | 'unknown'.
  final String owner;
  final String status; // OPEN | RESOLVED | SUPERSEDED | EXPIRED
  final String dueHint;
  final int createdAt;
  final double confidence;
  final String supersededBy;

  const OpenLoopSummary({
    required this.id,
    required this.description,
    this.type = 'generic',
    this.owner = 'unknown',
    this.status = 'OPEN',
    this.dueHint = '',
    required this.createdAt,
    this.confidence = 0.0,
    this.supersededBy = '',
  });

  bool get isOpen => status == 'OPEN';

  /// Transición explícita de estado (RESOLVED/SUPERSEDED/EXPIRED) sin
  /// tocar el resto de los campos.
  OpenLoopSummary withStatus(String newStatus, {String supersededBy = ''}) =>
      OpenLoopSummary(
        id: id,
        description: description,
        type: type,
        owner: owner,
        status: newStatus,
        dueHint: dueHint,
        createdAt: createdAt,
        confidence: confidence,
        supersededBy: supersededBy.isEmpty ? this.supersededBy : supersededBy,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'description': description,
    'type': type,
    'owner': owner,
    'status': status,
    'dueHint': dueHint,
    'createdAt': createdAt,
    'confidence': confidence,
    if (supersededBy.isNotEmpty) 'supersededBy': supersededBy,
  };

  factory OpenLoopSummary.fromJson(Map<String, dynamic> json) =>
      OpenLoopSummary(
        id: (json['id'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'generic',
        owner: (json['owner'] as String?) ?? 'unknown',
        status: (json['status'] as String?) ?? 'OPEN',
        dueHint: (json['dueHint'] as String?) ?? '',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        supersededBy: (json['supersededBy'] as String?) ?? '',
      );
}

/// Snapshot compacto del estado conversacional personal.
final class PersonalTurnState {
  static const int maxTopicChars = 120;
  static const int maxIntentChars = 80;
  static const int maxReferenceChars = 120;
  static const int maxOpenLoops = 8;

  final String currentTopic;
  final String latestIntent;
  final String unresolvedReference;
  final List<OpenLoopSummary> openLoops;
  final int stateUpdatedAt;
  final double confidence;

  const PersonalTurnState({
    this.currentTopic = '',
    this.latestIntent = '',
    this.unresolvedReference = '',
    this.openLoops = const [],
    required this.stateUpdatedAt,
    this.confidence = 0.0,
  });

  /// Merge idempotente: un campo nuevo vacío NO borra el valor previo.
  /// Los loops abiertos se conservan abiertos; la lista nueva reemplaza
  /// solo los que comparten id (resolución/supersession).
  PersonalTurnState merge({
    String? currentTopic,
    String? latestIntent,
    String? unresolvedReference,
    List<OpenLoopSummary>? openLoops,
    int? stateUpdatedAt,
    double? confidence,
  }) {
    final mergedLoops = <String, OpenLoopSummary>{
      for (final l in this.openLoops) l.id: l,
    };
    if (openLoops != null) {
      for (final l in openLoops) {
        mergedLoops[l.id] = l;
      }
    }
    var loops = mergedLoops.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (loops.length > maxOpenLoops) {
      loops = loops.sublist(0, maxOpenLoops);
    }
    return PersonalTurnState(
      currentTopic: _bounded(currentTopic ?? this.currentTopic, maxTopicChars),
      latestIntent: _bounded(latestIntent ?? this.latestIntent, maxIntentChars),
      unresolvedReference: _bounded(
        unresolvedReference ?? this.unresolvedReference,
        maxReferenceChars,
      ),
      openLoops: loops,
      stateUpdatedAt: stateUpdatedAt ?? this.stateUpdatedAt,
      confidence: confidence ?? this.confidence,
    );
  }

  static String _bounded(String raw, int max) =>
      raw.length <= max ? raw : raw.substring(0, max);

  Map<String, Object?> toJson() => {
    'currentTopic': currentTopic,
    'latestIntent': latestIntent,
    'unresolvedReference': unresolvedReference,
    'openLoops': openLoops.map((l) => l.toJson()).toList(),
    'stateUpdatedAt': stateUpdatedAt,
    'confidence': confidence,
  };

  factory PersonalTurnState.fromJson(Map<String, dynamic> json) {
    final rawLoops = json['openLoops'];
    final loops = <OpenLoopSummary>[];
    if (rawLoops is List) {
      for (final l in rawLoops.take(maxOpenLoops)) {
        if (l is Map) {
          loops.add(OpenLoopSummary.fromJson(l.cast<String, dynamic>()));
        }
      }
    }
    return PersonalTurnState(
      currentTopic: _bounded((json['currentTopic'] as String?) ?? '', maxTopicChars),
      latestIntent: _bounded((json['latestIntent'] as String?) ?? '', maxIntentChars),
      unresolvedReference: _bounded(
        (json['unresolvedReference'] as String?) ?? '',
        maxReferenceChars,
      ),
      openLoops: loops,
      stateUpdatedAt: (json['stateUpdatedAt'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
