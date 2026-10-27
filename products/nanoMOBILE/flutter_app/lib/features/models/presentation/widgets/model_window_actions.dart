// QUÉ: acciones del modelo, con favoritos visibles y disponibilidad real.
// CÓMO: oculta callbacks ausentes y delega el estado primario al botón común.
// POR QUÉ: evita ofrecer carga conversacional a OCR, voz o embeddings sin motor.
import 'package:flutter/material.dart';
import 'model_card_action_button.dart';
import 'model_catalog_types.dart';

class ModelWindowActions extends StatefulWidget {
  const ModelWindowActions({
    super.key,
    required this.item,
    required this.active,
    required this.isFavorite,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
    this.onToggleFavorite,
    this.onCompare,
    this.onShare,
  });
  final UnifiedModelItem item;
  final bool active, isFavorite;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete;
  final VoidCallback? onToggleFavorite, onCompare, onShare;
  @override
  State<ModelWindowActions> createState() => _ModelWindowActionsState();
}

class _ModelWindowActionsState extends State<ModelWindowActions> {
  late bool _favorite = widget.isFavorite;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item.isDownloading
        ? ModelUiStatus.downloading
        : item.installed && !item.runtimeReady
        ? ModelUiStatus.runtimeUnavailable
        : widget.active
        ? ModelUiStatus.active
        : item.installed
        ? ModelUiStatus.installed
        : ModelUiStatus.available;
    return Wrap(
      spacing: 4,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ModelCardActionButton(
          status: status,
          isActive: widget.active,
          isLoading: item.catalog?.loading ?? false,
          sizeGb: item.sizeGb,
          onUse: item.runtimeReady ? widget.onUse : null,
          onDownload: widget.onDownload,
          onCancel: widget.onCancel,
          onUnload: widget.onUnload,
        ),
        if (widget.onToggleFavorite != null)
          IconButton(
            tooltip: _favorite ? 'Quitar de favoritos' : 'Guardar favorito',
            isSelected: _favorite,
            icon: const Icon(Icons.favorite_border_rounded),
            selectedIcon: const Icon(Icons.favorite_rounded),
            onPressed: () {
              widget.onToggleFavorite!();
              setState(() => _favorite = !_favorite);
            },
          ),
        if (widget.onCompare != null &&
            item.runtimeReady &&
            !item.isSpecialized)
          IconButton(
            icon: const Icon(Icons.speed_rounded),
            tooltip: 'Comparar motores de texto',
            onPressed: widget.onCompare,
          ),
        if (widget.onShare != null)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir ficha',
            onPressed: widget.onShare,
          ),
        if (widget.onDelete != null && item.installed)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar archivo',
            color: Theme.of(context).colorScheme.error,
            onPressed: widget.onDelete,
          ),
      ],
    );
  }
}
