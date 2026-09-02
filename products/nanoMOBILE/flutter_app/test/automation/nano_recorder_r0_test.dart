import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/memory/nano_recorder.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';

void main() {
  test(
    'NanoRecorder ObjectMemory roundtrip preserves exact evidence/counters',
    () async {
      const key = UiObjectKey(
        concept: 'bluetooth',
        package: 'com.android.settings',
        appVersion: '42',
      );
      final t0 = DateTime.utc(2026, 8, 24, 12);
      var memory = const NanoObjectMemory()
          .recordSuccess(
            key,
            const UiSelectorEvidence(
              resourceId: 'com.android.settings:id/switch_widget',
              text: 'Bluetooth',
              role: 'switch',
              hierarchySignature: 'settings>row>switch',
            ),
            now: t0,
          )
          .recordSuccess(
            key,
            const UiSelectorEvidence(desc: 'Bluetooth', near: 'text=Bluetooth'),
            now: t0.add(const Duration(seconds: 1)),
          )
          .recordFailure(key, now: t0.add(const Duration(seconds: 2)));

      final sink = InMemoryRecorderSink();
      final recorder = NanoRecorder(sink);
      await recorder.persistObjectMemory(memory);
      final restored = await recorder.restoreObjectMemory();

      expect(restored.toJson(), memory.toJson());
      expect(restored.confidence(key), memory.confidence(key));
    },
  );

  test(
    'restoring repeated snapshots uses latest snapshot, not additive success',
    () async {
      const key = UiObjectKey(concept: 'wifi');
      final sink = InMemoryRecorderSink();
      final recorder = NanoRecorder(sink);

      final first = const NanoObjectMemory().recordSuccess(
        key,
        const UiSelectorEvidence(resourceId: 'wifi_1'),
        now: DateTime.utc(2026, 8, 24, 10),
      );
      final second = first.recordFailure(
        key,
        now: DateTime.utc(2026, 8, 24, 11),
      );

      await recorder.persistObjectMemory(first);
      await recorder.persistObjectMemory(second);

      final restored = await recorder.restoreObjectMemory();
      expect(restored.toJson(), second.toJson());
      expect(restored.confidence(key), 0.5);
    },
  );
}
