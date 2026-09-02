/// C13 — NanoRecorder: persistencia DURABLE de trazas y memoria de objetos UI.
///
/// R0: restauración exacta. No se recrea memoria llamando recordSuccess.
library;

import '../memory/object_memory.dart';

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

abstract interface class NanoRecorderSink {
  Future<void> append(Map<String, dynamic> record);
  Future<List<Map<String, dynamic>>> readAll();
}

class InMemoryRecorderSink implements NanoRecorderSink {
  final List<Map<String, dynamic>> _records = [];

  @override
  Future<void> append(Map<String, dynamic> record) async =>
      _records.add(record);

  @override
  Future<List<Map<String, dynamic>>> readAll() async => List.of(_records);
}

class NanoRecorder {
  final NanoRecorderSink _sink;
  const NanoRecorder(this._sink);

  Future<void> recordRun(RecordedRun run) => _sink.append(run.toJson());

  Future<void> persistObjectMemory(NanoObjectMemory memory) => _sink.append({
    'type': 'objectMemory',
    'schemaVersion': 2,
    'entries': memory.toJson(),
  });

  Future<NanoObjectMemory> restoreObjectMemory() async {
    List<dynamic>? latestEntries;
    for (final record in await _sink.readAll()) {
      if (record['type'] != 'objectMemory') continue;
      latestEntries = record['entries'] as List<dynamic>? ?? const [];
    }
    if (latestEntries == null) return const NanoObjectMemory();
    return NanoObjectMemory.fromJson(latestEntries);
  }

  Future<List<Map<String, dynamic>>> raw() => _sink.readAll();
}
