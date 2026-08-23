import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/memory/nano_recorder.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';

/// C13 — NanoRecorder: persistencia durable de trazas + memoria de objetos UI.
void main() {
  test('persiste y recarga una memoria de objetos UI (selectores verificados)',
      () async {
    final sink = InMemoryRecorderSink();
    final recorder = NanoRecorder(sink);

    var mem = const NanoObjectMemory().recordSuccess(
      const UiObjectKey(concept: 'bluetooth', package: 'com.android.settings'),
      const UiSelectorEvidence(resourceId: 'id_bt', text: 'Bluetooth'),
    );

    await recorder.persistObjectMemory(mem);

    final restored = await recorder.restoreObjectMemory();
    final resolved = restored.resolve(
      const UiObjectKey(concept: 'bluetooth', package: 'com.android.settings'),
    );
    expect(resolved?.resourceId, 'id_bt');
  });

  test('persiste trazas de ejecución y las lee', () async {
    final sink = InMemoryRecorderSink();
    final recorder = NanoRecorder(sink);

    await recorder.recordRun(
      const RecordedRun(
        goal: 'abre Bluetooth',
        status: 'completed',
        durationMs: 2300,
        path: 'android',
        resolvedSelector: 'id=id_bt',
      ),
    );

    final raw = await recorder.raw();
    expect(raw, hasLength(1));
    expect(raw.first['goal'], 'abre Bluetooth');
    expect(raw.first['status'], 'completed');
    expect(raw.first['resolvedSelector'], 'id=id_bt');
  });
}
