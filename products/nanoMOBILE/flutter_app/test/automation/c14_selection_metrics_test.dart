import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/benchmark/c14_metrics.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

C14Execution exec({
  required String goal,
  bool legacyFallback = false,
  bool koogInvoked = false,
  Duration llmLatency = Duration.zero,
  String selectionMode = 'none',
  bool goalSuccess = true,
}) => C14Execution(
  goal: goal,
  planValid: true,
  toolsGenerated: 0,
  toolsRejected: 0,
  steps: 1,
  path: selectionMode,
  llmLatency: llmLatency,
  toolLatency: Duration.zero,
  verification: goalSuccess
      ? AutomationResultStatus.completed
      : AutomationResultStatus.failed,
  retries: 0,
  replans: 0,
  cacheHit: false,
  goalSuccess: goalSuccess,
  totalLatency: Duration.zero,
  legacyFallback: legacyFallback,
  koogInvoked: koogInvoked,
  selectionMode: selectionMode,
  candidateCount: 1,
  candidateLatency: Duration.zero,
);

void main() {
  test('legacyFallbackRate / zeroLlmRate / koogInvocationRate', () {
    final ex = [
      exec(
        goal: 'chrome',
        selectionMode: 'deterministic',
        llmLatency: Duration.zero,
      ),
      exec(
        goal: 'unknown',
        selectionMode: 'legacyFallback',
        legacyFallback: true,
        llmLatency: const Duration(milliseconds: 120),
      ),
      exec(
        goal: 'whats',
        selectionMode: 'koog',
        koogInvoked: true,
        llmLatency: const Duration(milliseconds: 40),
      ),
    ];
    final report = const C14Gates().evaluate(ex);
    expect(report.legacyFallbackRate, closeTo(1 / 3, 0.001));
    expect(report.zeroLlmRate, closeTo(1 / 3, 0.001));
    expect(report.koogInvocationRate, closeTo(1 / 3, 0.001));
  });

  test('sin ejecuciones → rates 0 (no NaN)', () {
    final report = const C14Gates().evaluate(const []);
    expect(report.legacyFallbackRate, 0.0);
    expect(report.zeroLlmRate, 0.0);
    expect(report.koogInvocationRate, 0.0);
  });
}
