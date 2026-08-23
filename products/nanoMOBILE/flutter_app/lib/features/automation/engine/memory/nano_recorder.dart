/// C13 — NanoRecorder: persistencia DURABLE de trazas (ledger) y memoria de
/// objetos UI (C10). Permite auditabilidad y el benchmark C14-B (100+ runs).
///
/// Los [AutomationTrace] del ledger y la [NanoObjectMemory] son en memoria
/// hasta ahora; el recorder los serializa a un [NanoRecorderSink] (archivo o
/// backend) de forma append-only y los recarga al arrancar.
///
/// No acopla a un formato de archivo concreto: el sink es una interfaz inyectable
/// (DIP) — archivo local, backend, o el benchmark.
library;

import '../memory/object_memory.dart';

/// Un registro serializable de una traza (goal / status / duration / selectores
/// usados) para persistencia y análisis agregado (C14-B).
class RecordedRun {
  final String goal;
  final String status;
  final int durationMs;
  final String path;
  final String? resolvedSelector;

  const RecordedRun({
    required this.goal,
    required this.status,
    required this.durationMs,
    required this.path,
    this.resolvedSelector,
  });

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'status': status,
        'durationMs': durationMs,
        'path': path,
        'resolvedSelector': resolvedSelector,
      };
}

/// Sink de persistencia (DIP): escribe/lee registros serializables.
abstract interface class NanoRecorderSink {
  Future<void> append(Map<String, dynamic> record);
  Future<List<Map<String, dynamic>>> readAll();
}

/// Persistencia en memoria (para tests / default). No es durable, pero permite
/// ejercitar el flujo recorder sin IO.
class InMemoryRecorderSink implements NanoRecorderSink {
  final List<Map<String, dynamic>> _records = [];
  @override
  Future<void> append(Map<String, dynamic> record) async =>
      _records.add(record);
  @override
  Future<List<Map<String, dynamic>>> readAll() async => List.of(_records);
}

/// Recorder: serializa trazas y memoria al sink; recarga para reconstruir.
class NanoRecorder {
  final NanoRecorderSink _sink;
  const NanoRecorder(this._sink);

  /// Persiste una traza de ejecución.
  Future<void> recordRun(RecordedRun run) =>
      _sink.append(run.toJson());

  /// Persiste la memoria de objetos UI (para no perder selectores verificados).
  Future<void> persistObjectMemory(NanoObjectMemory memory) =>
      _sink.append({'type': 'objectMemory', 'entries': memory.toJson()});

  /// Reconstruye la memoria de objetos desde el sink (selectores verificados).
  Future<NanoObjectMemory> restoreObjectMemory() async {
    var mem = const NanoObjectMemory();
    for (final r in await _sink.readAll()) {
      final type = r['type'] as String?;
      if (type != 'objectMemory') continue;
      for (final e in (r['entries'] as List<dynamic>? ?? const [])) {
        final m = e as Map<String, dynamic>;
        mem = mem.recordSuccess(
          UiObjectKey(
            concept: m['concept'] as String? ?? '',
            package: m['package'] as String? ?? '',
            appVersion: m['appVersion'] as String? ?? '',
          ),
          UiSelectorEvidence(
            resourceId: m['resourceId'] as String?,
            text: m['text'] as String?,
          ),
        );
      }
    }
    return mem;
  }

  /// Récords crudos (para diagnóstico / el benchmark).
  Future<List<Map<String, dynamic>>> raw() => _sink.readAll();
}
