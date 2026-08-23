/// Run del benchmark C14-A — UNA sola fuente de verdad.
///
/// Tanto el botón debug de `/automation` como el `integration_test` llaman
/// a [runC14Benchmark] con un [ProviderContainer]. Nunca hay dos
/// implementaciones del benchmark. El run:
///   1. Captura [BenchmarkContext] (reproducible).
///   2. Corre el preflight (si falta el modelo → aborta con código, no corre
///      10 tareas rojas).
///   3. Si preflight pasa → ejecuta la suite con el coordinator REAL y
///      produce [C14BenchmarkReport].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

import '../application/automation_coordinator_provider.dart';
import 'c14_benchmark.dart';
import 'c14_context.dart';
import 'c14_metrics.dart';
import 'c14_preflight.dart';

class C14RunResult {
  final BenchmarkContext context;
  final C14PreflightResult preflight;

  /// null si el preflight falló (no se ejecutó la suite).
  final C14BenchmarkReport? report;
  final Duration total;

  const C14RunResult({
    required this.context,
    required this.preflight,
    required this.report,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'benchmark': 'C14-A',
        ...context.toJson(),
        'preflight': {
          'pass': preflight.pass,
          'failCode': preflight.failCode?.name,
          'checks': [
            for (final c in preflight.checks)
              {'name': c.name, 'ok': c.ok, 'detail': c.detail},
          ],
        },
        'report': report == null
            ? null
            : {
                'total': report!.total,
                'passed': report!.passed,
                'successRate': report!.successRate,
                'gates': [
                  for (final g in report!.gates)
                    {
                      'name': g.name,
                      'value': g.value,
                      'threshold': g.threshold,
                      'pass': g.pass,
                    },
                ],
                'executions': [
                  for (final e in report!.executions)
                    {
                      'goal': e.goal,
                      'planValid': e.planValid,
                      'toolsGenerated': e.toolsGenerated,
                      'toolsRejected': e.toolsRejected,
                      'steps': e.steps,
                      'path': e.path,
                      'llmLatencyMs': e.llmLatency.inMilliseconds,
                      'toolLatencyMs': e.toolLatency.inMilliseconds,
                      'verification': e.verification.name,
                      'retries': e.retries,
                      'replans': e.replans,
                      'cacheHit': e.cacheHit,
                      'goalSuccess': e.goalSuccess,
                      'totalLatencyMs': e.totalLatency.inMilliseconds,
                    },
                ],
              },
        'totalMs': total.inMilliseconds,
      };
}

/// Ejecuta el benchmark C14-A. Único punto de entrada (debug UI + integration).
Future<C14RunResult> runC14Benchmark(
  ProviderContainer container, {
  void Function(int index, String goal)? onStart,
  void Function(C14Execution)? onExecution,
}) async {
  final wall = Stopwatch()..start();
  final engine = container.read(runtimeEngineProvider);
  final settings = container.read(settingsProvider);

  final context = BenchmarkContext.capture(
    model: engine.modelPath ?? '',
    temperature: settings.temperature,
  );

  final preflight = await const C14Preflight().run(
    runtimeAlive: engine.isLive,
    modelLoaded: engine.phase == EnginePhase.ready,
    accessibilityEnabled: await _accessibilityEnabled(),
    coordinatorReady: true, // DI construye o lanza (se propaga como error).
    policyConfigured: true, // agentAutomationMode siempre tiene valor (enum).
    deviceUnlocked: true, // sin fuente verificable todavía (ver nota).
    screenInteractive: true,
  );

  if (!preflight.pass) {
    wall.stop();
    return C14RunResult(
      context: context,
      preflight: preflight,
      report: null,
      total: wall.elapsed,
    );
  }

  final base = container.read(automationCoordinatorProvider);
  final benchmark = C14Benchmark(
    buildCoordinator: (sink) => base.withSink(sink),
  );
  final report = await benchmark.run(
    defaultSuite,
    onStart: onStart,
    onExecution: onExecution,
  );
  wall.stop();
  return C14RunResult(
    context: context,
    preflight: preflight,
    report: report,
    total: wall.elapsed,
  );
}

Future<bool> _accessibilityEnabled() async {
  try {
    final status = await NanoRuntimeApi.instance.agentStatus();
    if (status == null) return false;
    return status['connected'] == true || status['enabled'] == true;
  } catch (_) {
    return false;
  }
}
