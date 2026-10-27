// model_download_progress.dart — Progreso accesible para tarjetas y ficha del modelo.
import 'package:flutter/material.dart';
import '../../domain/local_model.dart';

/// Distingue descarga medible de verificación, donde el avance no es lineal.
class ModelDownloadProgress extends StatelessWidget {
  const ModelDownloadProgress({super.key, required this.model});

  final LocalModel model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final verifying = model.downloadState == ModelDownloadState.verifying;
    final progress = model.progress.clamp(0.0, 1.0);
    final value = verifying || progress == 0 ? null : progress;
    final label = verifying ? 'Verificando integridad…' : 'Descargando modelo…';

    return Semantics(
      label: label,
      value: value == null ? null : '${(value * 100).round()} por ciento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (value != null)
                Text(
                  '${(value * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value,
            minHeight: 5,
            color: colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
