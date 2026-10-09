// QUÉ: acciones reales del catálogo con una presentación neutra Material.
// CÓMO: conserva la prioridad de estados y los callbacks de carga y descarga.
// POR QUÉ: comunica el estado mediante texto e iconos, no con colores competidores.
import 'package:flutter/material.dart';
import 'model_screen_helpers.dart';
import 'model_catalog_surface.dart';

class ModelCardActionButton extends StatelessWidget {
  final ModelUiStatus status;
  final bool isActive, isLoading;
  final double sizeGb;
  final VoidCallback? onUse, onDownload, onCancel, onUnload;
  const ModelCardActionButton({
    super.key,
    required this.status,
    required this.isActive,
    required this.isLoading,
    required this.sizeGb,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
  });

  // El indicador solo aparece durante una carga real; no anima tarjetas inactivas.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (isLoading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }
    // Activo conserva su acción de liberar memoria; solo cambia su presentación.
    final (label, icon, action, tooltip) = isActive
        ? (
            'Activo',
            Icons.check_circle_outline,
            onUnload,
            'Liberar modelo activo',
          )
        : status == ModelUiStatus.installed
        ? ('Cargar', Icons.play_arrow_rounded, onUse, 'Cargar modelo')
        : status == ModelUiStatus.downloading
        ? ('Cancelar', Icons.close_rounded, onCancel, 'Cancelar descarga')
        : (
            '${sizeGb.toStringAsFixed(1)} GB',
            Icons.download_rounded,
            onDownload,
            'Descargar modelo',
          );
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: modelCatalogSurface(context),
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: Theme.of(context).textTheme.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
