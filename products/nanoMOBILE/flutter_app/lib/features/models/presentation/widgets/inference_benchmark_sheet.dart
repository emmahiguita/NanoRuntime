// inference_benchmark_sheet.dart
// QUÉ HACE: Modal Material Expressive para comparar el rendimiento de llama.cpp (GGUF) vs LiteRT-LM (.litertlm).
// CÓMO FUNCIONA: Ejecuta inferencia sobre la misma tarea en ambos motores y muestra TTFT, tokens/s y RAM.
// POR QUÉ: Permite tomar decisiones basadas en telemetría objetiva para el hardware del usuario.
library;

import 'package:flutter/material.dart';
import '../../../../core/services/nano_inference_coordinator.dart';

/// Despliega el modal de benchmarking comparativo de motores.
Future<void> showInferenceBenchmarkSheet(
  BuildContext context, {
  required NanoInferenceCoordinator coordinator,
  required String ggufModelPath,
  required String liteRtModelPath,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InferenceBenchmarkSheet(
      coordinator: coordinator,
      ggufPath: ggufModelPath,
      liteRtPath: liteRtModelPath,
    ),
  );
}

class _InferenceBenchmarkSheet extends StatefulWidget {
  final NanoInferenceCoordinator coordinator;
  final String ggufPath;
  final String liteRtPath;

  const _InferenceBenchmarkSheet({
    required this.coordinator,
    required this.ggufPath,
    required this.liteRtPath,
  });

  @override
  State<_InferenceBenchmarkSheet> createState() => _InferenceBenchmarkSheetState();
}

class _InferenceBenchmarkSheetState extends State<_InferenceBenchmarkSheet> {
  bool _running = false;
  List<EngineBenchmarkResult> _results = const [];

  // QUÉ HACE: Ejecuta el test comparativo en ambos motores respetando exclusión mutua.
  // CÓMO FUNCIONA: Delega la orquestación a NanoInferenceCoordinator sin colisionar en RAM.
  Future<void> _startBenchmark() async {
    setState(() {
      _running = true;
      _results = const [];
    });

    try {
      final res = await widget.coordinator.runBenchmarkComparison(
        prompt: 'Resume en una frase la importancia de la computación local.',
        ggufModelPath: widget.ggufPath,
        liteRtModelPath: widget.liteRtPath,
      );
      if (mounted) {
        setState(() {
          _results = res;
        });
      }
    } catch (e) {
      debugPrint('[benchmark] error en modal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height || size.height < 500;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(isLandscape ? 20 : 28)),
      ),
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 20 : 24,
        isLandscape ? 10 : 16,
        isLandscape ? 20 : 24,
        MediaQuery.viewInsetsOf(context).bottom + (isLandscape ? 12 : 24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: isLandscape ? 24 : 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
            Text(
              'Benchmark: llama.cpp vs LiteRT-LM',
              style: isLandscape ? theme.textTheme.titleMedium : theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Compara latencia al primer token (TTFT), velocidad y estabilidad en este dispositivo.',
              style: (isLandscape ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isLandscape ? 12 : 20),
            if (_running) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Center(
                child: Text('Evaluando motores (exclusión mutua activa)…', style: theme.textTheme.bodySmall),
              ),
            ] else if (_results.isNotEmpty) ...[
              for (final r in _results)
                _BenchmarkRow(result: r, compact: isLandscape),
              const SizedBox(height: 12),
            ],
            SizedBox(height: isLandscape ? 8 : 16),
            FilledButton.icon(
              onPressed: _running ? null : _startBenchmark,
              icon: Icon(Icons.speed_rounded, size: isLandscape ? 18 : 20),
              label: Text(_running ? 'Midiendo…' : 'Iniciar Benchmark Comparativo'),
              style: FilledButton.styleFrom(minimumSize: Size.fromHeight(isLandscape ? 40 : 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para mostrar las métricas de un motor individual
class _BenchmarkRow extends StatelessWidget {
  final EngineBenchmarkResult result;
  final bool compact;

  const _BenchmarkRow({required this.result, required this.compact});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLiteRt = result.engine == LocalEngineType.liteRt;
    final name = isLiteRt ? 'LiteRT-LM (.litertlm)' : 'llama.cpp (GGUF)';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isLiteRt ? Icons.bolt_rounded : Icons.memory_rounded, color: cs.primary, size: compact ? 18 : 22),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 12 : 14)),
            ],
          ),
          Text(
            'TTFT: ${result.ttftMs}ms | ${result.tokensPerSec.toStringAsFixed(1)} t/s',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: compact ? 11 : 13),
          ),
        ],
      ),
    );
  }
}
