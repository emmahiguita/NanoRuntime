// model_download_feedback.dart — Avisos Material 3 para resultados reales de descarga.
import 'package:flutter/material.dart';
import '../../domain/local_model.dart';

/// Presenta éxito, cancelación o fallo solo tras el estado final del descargador.
abstract final class ModelDownloadFeedback {
  static void show(BuildContext context, LocalModel model) {
    final messenger = ScaffoldMessenger.of(context);
    final colors = Theme.of(context).colorScheme;
    final cancelled = model.error?.toLowerCase().contains('cancel') ?? false;
    final success = model.downloadState == ModelDownloadState.installed;
    final title = success
        ? 'Modelo descargado y verificado'
        : cancelled
        ? 'Descarga cancelada'
        : 'No se pudo descargar el modelo';
    final detail = success
        ? '${model.name} está listo para cargar.'
        : cancelled
        ? model.name
        : '${model.name}: ${model.error ?? 'error desconocido'}';
    final background = success
        ? colors.tertiaryContainer
        : cancelled
        ? colors.surfaceContainerHigh
        : colors.errorContainer;
    final foreground = success
        ? colors.onTertiaryContainer
        : cancelled
        ? colors.onSurface
        : colors.onErrorContainer;

    // MaterialBanner usa la superficie y el movimiento del tema Material 3 activo.
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: background,
          leading: Icon(
            success
                ? Icons.verified_rounded
                : cancelled
                ? Icons.info_outline_rounded
                : Icons.error_outline_rounded,
            color: foreground,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: Text('Cerrar', style: TextStyle(color: foreground)),
            ),
          ],
        ),
      );
  }
}
