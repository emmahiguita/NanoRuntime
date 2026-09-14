import 'package:flutter/foundation.dart';

/// Clasificación de la fuente original de un registro de contexto.
enum NanoContextSourceKind {
  nanoChat,
  externalAi,
  projectFile,
  repository,
  terminal,
  execution,
  memory,
  browserCapture,
  importedArchive,
}

/// Nivel de autoridad del contexto (evita que un chat antiguo sobrescriba el estado real).
enum NanoContextAuthority {
  /// Conversación, propuesta o decisión histórica: útil, pero no prueba estado.
  historical,

  /// Observación capturada desde UI/navegador/terminal en un instante concreto.
  observed,

  /// Fuente que representa el estado actual consultado (repo/archivo/runtime real).
  currentState,
}

/// Metadatos obligatorios de procedencia para auditar de dónde vino cada dato.
@immutable
class NanoContextProvenance {
  const NanoContextProvenance({
    required this.provider,
    required this.sourceId,
    required this.sourceKind,
    required this.capturedAt,
    required this.authority,
    this.conversationId,
    this.originalUri,
    this.contentHash,
    this.metadata = const {},
  });

  final String provider;
  final String sourceId;
  final NanoContextSourceKind sourceKind;
  final DateTime capturedAt;
  final NanoContextAuthority authority;
  final String? conversationId;
  final String? originalUri;
  final String? contentHash;
  final Map<String, Object?> metadata;
}

@immutable
class NanoCodeArtifact {
  const NanoCodeArtifact({
    required this.content,
    this.language,
    this.probableFileName,
    this.contentHash,
    this.metadata = const {},
  });

  final String content;
  final String? language;
  final String? probableFileName;
  final String? contentHash;
  final Map<String, Object?> metadata;
}

@immutable
class NanoContextRecord {
  const NanoContextRecord({
    required this.id,
    required this.text,
    required this.provenance,
    required this.createdAt,
    this.projectId,
    this.role,
    this.codeArtifacts = const [],
    this.metadata = const {},
  });

  final String id;
  final String text;
  final NanoContextProvenance provenance;
  final DateTime createdAt;
  final String? projectId;
  final String? role;
  final List<NanoCodeArtifact> codeArtifacts;
  final Map<String, Object?> metadata;
}

class NanoContextQuery {
  const NanoContextQuery({
    required this.text,
    this.projectId,
    this.sourceKinds = const {},
    this.minimumAuthority,
    this.limit = 12,
  }) : assert(limit > 0);

  final String text;
  final String? projectId;
  final Set<NanoContextSourceKind> sourceKinds;
  final NanoContextAuthority? minimumAuthority;
  final int limit;
}

class NanoContextSearchHit {
  const NanoContextSearchHit({
    required this.record,
    required this.score,
    this.reason,
  });

  final NanoContextRecord record;
  final double score;
  final String? reason;
}

class NanoContextSelection {
  const NanoContextSelection({
    required this.scopeId,
    required this.recordIds,
    required this.updatedAt,
  });

  final String scopeId;
  final List<String> recordIds;
  final DateTime updatedAt;
}

class NanoContextBundle {
  const NanoContextBundle({
    required this.records,
    required this.historical,
    required this.observed,
    required this.currentState,
  });

  final List<NanoContextRecord> records;
  final List<NanoContextRecord> historical;
  final List<NanoContextRecord> observed;
  final List<NanoContextRecord> currentState;

  bool get hasCurrentStateEvidence => currentState.isNotEmpty;
}

abstract interface class NanoContextRepository {
  Future<void> upsertAll(Iterable<NanoContextRecord> records);
  Future<List<NanoContextSearchHit>> search(NanoContextQuery query);
  Future<List<NanoContextRecord>> getByIds(Iterable<String> ids);
  Future<void> saveSelection(NanoContextSelection selection);
  Future<NanoContextSelection?> loadSelection(String scopeId);
}

/// Repositorio en memoria por defecto para inicialización sin SQLite obligatoria.
class InMemoryNanoContextRepository implements NanoContextRepository {
  final Map<String, NanoContextRecord> _storage = {};
  final Map<String, NanoContextSelection> _selections = {};

  @override
  Future<void> upsertAll(Iterable<NanoContextRecord> records) async {
    for (final r in records) {
      _storage[r.id] = r;
    }
  }

  @override
  Future<List<NanoContextSearchHit>> search(NanoContextQuery query) async {
    final hits = <NanoContextSearchHit>[];
    final needle = query.text.toLowerCase();
    for (final r in _storage.values) {
      if (query.projectId != null && r.projectId != query.projectId) continue;
      if (query.sourceKinds.isNotEmpty &&
          !query.sourceKinds.contains(r.provenance.sourceKind)) {
        continue;
      }
      final hay = r.text.toLowerCase();
      if (hay.contains(needle)) {
        hits.add(NanoContextSearchHit(record: r, score: 1.0));
      }
      if (hits.length >= query.limit) break;
    }
    return hits;
  }

  @override
  Future<List<NanoContextRecord>> getByIds(Iterable<String> ids) async {
    final list = <NanoContextRecord>[];
    for (final id in ids) {
      final found = _storage[id];
      if (found != null) list.add(found);
    }
    return list;
  }

  @override
  Future<void> saveSelection(NanoContextSelection selection) async {
    _selections[selection.scopeId] = selection;
  }

  @override
  Future<NanoContextSelection?> loadSelection(String scopeId) async {
    return _selections[scopeId];
  }
}

/// Contexto Unificado de Nano AI (Clean Architecture).
@immutable
class NanoUnifiedContext {
  const NanoUnifiedContext({
    required this.batteryPct,
    required this.ramAvailableMb,
    required this.storageFreeGb,
    required this.isCharging,
    required this.recentMessagesCount,
    this.lastExecutedTool,
    this.lastToolResultStatus,
  });

  final int batteryPct;
  final int ramAvailableMb;
  final double storageFreeGb;
  final bool isCharging;
  final int recentMessagesCount;
  final String? lastExecutedTool;
  final String? lastToolResultStatus;

  String toPromptSummary() {
    final buffer = StringBuffer()
      ..writeln('[Nano Context Hub]')
      ..writeln(
        'Estado del dispositivo: Batería $batteryPct% ${isCharging ? "(Cargando)" : ""}, RAM libre ${ramAvailableMb}MB, Disco libre ${storageFreeGb.toStringAsFixed(1)}GB.',
      )
      ..writeln('Mensajes en sesión: $recentMessagesCount.');
    if (lastExecutedTool != null) {
      buffer.writeln(
        'Última acción ejecutada: "$lastExecutedTool" (Estado: ${lastToolResultStatus ?? "ejecutado"}).',
      );
    }
    return buffer.toString();
  }
}

/// Servicio Hub de Contexto para el Agente Nano.
class NanoContextHub {
  NanoContextHub([NanoContextRepository? repository])
    : _repository = repository ?? InMemoryNanoContextRepository();

  final NanoContextRepository _repository;
  NanoUnifiedContext? _lastContext;

  NanoUnifiedContext? get currentContext => _lastContext;

  void updateContext({
    required int batteryPct,
    required int ramAvailableMb,
    required double storageFreeGb,
    required bool isCharging,
    required int recentMessagesCount,
    String? lastExecutedTool,
    String? lastToolResultStatus,
  }) {
    _lastContext = NanoUnifiedContext(
      batteryPct: batteryPct,
      ramAvailableMb: ramAvailableMb,
      storageFreeGb: storageFreeGb,
      isCharging: isCharging,
      recentMessagesCount: recentMessagesCount,
      lastExecutedTool: lastExecutedTool,
      lastToolResultStatus: lastToolResultStatus,
    );
  }

  Future<void> ingest(Iterable<NanoContextRecord> records) async {
    final materialized = records.toList(growable: false);
    for (final record in materialized) {
      _validate(record);
    }
    if (materialized.isEmpty) return;
    await _repository.upsertAll(materialized);
  }

  Future<List<NanoContextSearchHit>> search(NanoContextQuery query) =>
      _repository.search(query);

  Future<void> setActiveContext({
    required String scopeId,
    required Iterable<String> recordIds,
  }) async {
    final ids = recordIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    await _repository.saveSelection(
      NanoContextSelection(
        scopeId: scopeId,
        recordIds: List.unmodifiable(ids),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Recupera el contexto activo particionando en una sola pasada (optimización de memoria/CPU).
  Future<NanoContextBundle> activeContext(String scopeId) async {
    final selection = await _repository.loadSelection(scopeId);
    if (selection == null || selection.recordIds.isEmpty) {
      return const NanoContextBundle(
        records: [],
        historical: [],
        observed: [],
        currentState: [],
      );
    }

    final fetched = await _repository.getByIds(selection.recordIds);
    final byId = {for (final record in fetched) record.id: record};
    final ordered = <NanoContextRecord>[];
    final historical = <NanoContextRecord>[];
    final observed = <NanoContextRecord>[];
    final currentState = <NanoContextRecord>[];

    // Particionado eficiente O(n) en un solo recorrido
    for (final id in selection.recordIds) {
      final record = byId[id];
      if (record != null) {
        ordered.add(record);
        switch (record.provenance.authority) {
          case NanoContextAuthority.historical:
            historical.add(record);
            break;
          case NanoContextAuthority.observed:
            observed.add(record);
            break;
          case NanoContextAuthority.currentState:
            currentState.add(record);
            break;
        }
      }
    }

    return NanoContextBundle(
      records: List.unmodifiable(ordered),
      historical: List.unmodifiable(historical),
      observed: List.unmodifiable(observed),
      currentState: List.unmodifiable(currentState),
    );
  }

  /// Validación de integridad y límite de tamaño para evitar desbordamiento de RAM (OOM).
  static const int maxRecordTextBytes = 64 * 1024; // 64 KB máx por record

  void _validate(NanoContextRecord record) {
    if (record.id.trim().isEmpty) {
      throw ArgumentError.value(
        record.id,
        'record.id',
        'No puede estar vacío.',
      );
    }
    if (record.provenance.provider.trim().isEmpty) {
      throw ArgumentError.value(
        record.provenance.provider,
        'provenance.provider',
        'La procedencia es obligatoria.',
      );
    }
    if (record.provenance.sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        record.provenance.sourceId,
        'provenance.sourceId',
        'La fuente concreta es obligatoria.',
      );
    }
    if (record.text.length > maxRecordTextBytes) {
      throw ArgumentError.value(
        record.text.length,
        'record.text',
        'El payload de texto excede el límite seguro de $maxRecordTextBytes caracteres (protección OOM).',
      );
    }
  }
}
