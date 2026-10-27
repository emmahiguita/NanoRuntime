// Presentación adaptativa: errores visibles y métricas ausentes como «no disponible».
import 'package:flutter/material.dart';
import '../../../../core/services/nano_inference_coordinator.dart';

class InferenceBenchmarkRow extends StatelessWidget {
  final EngineBenchmarkResult result;
  const InferenceBenchmarkRow({super.key, required this.result});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.engine == LocalEngineType.liteRt
                  ? 'LiteRT-LM · Gemma'
                  : 'llama.cpp · GGUF',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            if (result.error != null)
              Text(
                result.error!,
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    'Primer texto: ${result.ttftMs?.toString() ?? "no disponible"} ms',
                  ),
                  Text(
                    'Tokens/s: ${result.tokensPerSec?.toStringAsFixed(1) ?? "no disponible"}',
                  ),
                  Text('Total: ${result.durationMs} ms'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
