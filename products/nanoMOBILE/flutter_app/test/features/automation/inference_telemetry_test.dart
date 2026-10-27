import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/model/inference_telemetry.dart';

void main() {
  setUp(InferenceTelemetry.reset);

  test('complete conserva una duración total real en el resumen', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    InferenceTelemetry.begin(
      conversationId: 'chat-telemetry',
      requestId: 'request-telemetry-001',
      promptChars: 350,
      historyEntries: 2,
      queuedAtMs: now - 5,
    );
    await Future<void>.delayed(const Duration(milliseconds: 3));
    InferenceTelemetry.complete(
      requestId: 'request-telemetry-001',
      prefillMs: 2,
      decodeMs: 1,
      generatedTokens: 4,
    );

    final summary = InferenceTelemetry.summary();
    expect(summary['samples'], 1);
    expect(summary['avgTotalMs'], greaterThan(0));
    expect(summary['avgPrefillMs'], 2);
    expect(summary['avgDecodeMs'], 1);
  });
}
