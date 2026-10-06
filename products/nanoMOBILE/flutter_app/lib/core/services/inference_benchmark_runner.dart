// Mide el mismo prompt y presupuesto en ambos motores. null = dato no expuesto.
// Un fallo es un resultado fallido, nunca una velocidad o latencia de ejemplo.
import 'nano_inference_coordinator.dart';

class EngineBenchmarkResult {
  final LocalEngineType engine;
  final int? ttftMs, totalTokens;
  final double? tokensPerSec;
  final int durationMs;
  final String? error;
  const EngineBenchmarkResult({
    required this.engine,
    this.ttftMs,
    this.tokensPerSec,
    this.totalTokens,
    required this.durationMs,
    this.error,
  });
}

Future<EngineBenchmarkResult> measureLocalEngine(
  NanoInferenceCoordinator coordinator,
  LocalEngineType type,
  String path,
  String prompt,
) async {
  final watch = Stopwatch();
  int? firstToken, count;
  double? tps;
  try {
    if (!await coordinator.switchToEngine(type, modelPath: path)) {
      throw StateError(coordinator.llama.reason ?? 'El modelo no está listo');
    }
    watch.start();
    final request = coordinator.llama.client.generateStream(
      prompt: prompt,
      maxTokens: 64,
      temperature: 0.3,
      topP: 0.95,
    );
    var content = false;
    try {
      await for (final token in request.stream.timeout(
        const Duration(seconds: 180),
      )) {
        if (token.content.isNotEmpty) {
          content = true;
          firstToken ??= watch.elapsedMilliseconds;
        }
        if (token.stop) {
          tps = token.tps;
          count = (token.timings?['predicted_n'] as num?)?.toInt();
          break;
        }
      }
    } finally {
      request.client.close();
      watch.stop();
    }
    if (!content) throw StateError('El modelo no produjo respuesta');
    if (type == LocalEngineType.liteRt) {
      count = coordinator.liteRt.lastMetrics.totalTokens;
    } else if (type == LocalEngineType.mnn) {
      count = (coordinator.mnn.lastMetrics['generated_tokens'] as num?)?.toInt();
    }
    return EngineBenchmarkResult(
      engine: type,
      ttftMs: firstToken,
      tokensPerSec: tps,
      totalTokens: count,
      durationMs: watch.elapsedMilliseconds,
    );
  } catch (error) {
    watch.stop();
    return EngineBenchmarkResult(
      engine: type,
      durationMs: watch.elapsedMilliseconds,
      error: error.toString(),
    );
  }
}
