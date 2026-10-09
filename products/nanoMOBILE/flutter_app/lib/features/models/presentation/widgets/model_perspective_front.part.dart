// QUÉ: anverso del catálogo en tonos neutros y sin borde de selección verde.
// CÓMO: reutiliza estado y callbacks originales; no contiene lógica de motores.
// POR QUÉ: separa presentación de animación sin duplicar tarjetas o rutas.
part of 'model_perspective_card.dart';

extension _ModelPerspectiveFront on _ModelPerspectiveCardState {
  Widget _buildFront(NanoColors colors) {
    final item = widget.item;
    final cardContent = Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTapDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Model3DLogoBox(item: item, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            ModelTagBadge(
                              label: item.typeTag,
                              color: colors.onSurfaceVariant,
                            ),
                            if (item.isRecommendedForNano) ...[
                              const SizedBox(width: 4),
                              ModelTagBadge(
                                label: 'Sugerido',
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.format} • ${item.sizeGb.toStringAsFixed(1)} GB${item.ramGb > 0 ? ' • RAM ≈${item.ramGb.toStringAsFixed(1)} GB' : ''}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ModelCardActionButton(
                              status: widget.status,
                              isActive: widget.isActive,
                              isLoading: widget.isLoading,
                              sizeGb: item.sizeGb,
                              onUse: widget.onUse,
                              onDownload: widget.onDownload,
                              onCancel: widget.onCancel,
                              onUnload: widget.onUnload,
                            ),
                            const Spacer(),
                            // Papelera iOS visible: rojo solo para la acción destructiva real.
                            // Mantiene el callback con confirmación; no borra desde la tarjeta.
                            if (item.installed && widget.onDelete != null)
                              IconButton(
                                icon: const Icon(
                                  CupertinoIcons.trash,
                                  size: 20,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Eliminar modelo descargado',
                                color: Theme.of(context).colorScheme.error,
                                onPressed: widget.onDelete,
                              ),
                            IconButton(
                              icon: const Icon(Icons.flip_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Ver detalles técnicos',
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                              onPressed: _toggleFlip,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // El avance y la verificación reflejan el estado real del descargador.
              if (item.isDownloading && item.catalog != null) ...[
                const SizedBox(height: 10),
                ModelDownloadProgress(model: item.catalog!),
              ],
            ],
          ),
        ),
      ),
    );

    return cardContent;
  }
}
