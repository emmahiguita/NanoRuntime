// Comparación manual opt-in. La hoja muestra errores, no fabrica resultados al fallar.
// Usa Material 3 y desplazamiento para conservar controles legibles en horizontal.
import 'package:flutter/material.dart';
import '../../../../core/services/nano_inference_coordinator.dart';
import 'inference_benchmark_row.dart';

Future<void> showInferenceBenchmarkSheet(
  BuildContext context, {
  required NanoInferenceCoordinator coordinator,
  required String ggufModelPath,
  required String liteRtModelPath,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _BenchmarkSheet(
    coordinator: coordinator,
    ggufPath: ggufModelPath,
    liteRtPath: liteRtModelPath,
  ),
);

class _BenchmarkSheet extends StatefulWidget {
  final NanoInferenceCoordinator coordinator;
  final String ggufPath, liteRtPath;
  const _BenchmarkSheet({
    required this.coordinator,
    required this.ggufPath,
    required this.liteRtPath,
  });
  @override
  State<_BenchmarkSheet> createState() => _BenchmarkSheetState();
}

class _BenchmarkSheetState extends State<_BenchmarkSheet> {
  bool _running = false;
  String? _error;
  List<EngineBenchmarkResult> _results = [];
  Future<void> _measure() async {
    setState(() {
      _running = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await widget.coordinator.runBenchmarkComparison(
        prompt: 'Resume en una frase la importancia de la computación local.',
        ggufModelPath: widget.ggufPath,
        liteRtModelPath: widget.liteRtPath,
      );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Comparar motores locales', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Mismo prompt y límite de 64 tokens. La carga inicial se excluye del tiempo de respuesta.',
          ),
          const SizedBox(height: 12),
          if (_running) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          for (final result in _results) InferenceBenchmarkRow(result: result),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _measure,
            icon: const Icon(Icons.speed_rounded),
            label: Text(_running ? 'Midiendo…' : 'Comparar'),
          ),
        ],
      ),
    );
  }
}
