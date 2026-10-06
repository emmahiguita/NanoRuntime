// model_perspective_card.dart — Tarjeta con perspectiva 3D, flip interactivo y Hero.
// QUÉ HACE: Renderiza la tarjeta con portada 3D a la izquierda, textos sueltos a la derecha y Hero.
// CÓMO FUNCIONA: Aplica rotación tridimensional en el eje Y (Matrix4 m44), flip anverso/reverso y vuelo Hero.
// POR QUÉ: Eleva la jerarquía visual del módulo de modelos manteniendo modularidad estricta (< 200 líneas).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_3d_flip_flight.dart';
import 'model_3d_logo_box.dart';
import 'model_card_action_button.dart';
import 'model_catalog_types.dart';
import 'model_download_progress.dart';
import 'model_perspective_back.dart';

class ModelPerspectiveCard extends StatefulWidget {
  final UnifiedModelItem item;
  final bool isActive, isLoading;
  final ModelUiStatus status;
  final VoidCallback onTapDetails;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete;

  const ModelPerspectiveCard({
    super.key,
    required this.item,
    required this.isActive,
    required this.isLoading,
    required this.status,
    required this.onTapDetails,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
  });

  @override
  State<ModelPerspectiveCard> createState() => _ModelPerspectiveCardState();
}

class _ModelPerspectiveCardState extends State<ModelPerspectiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_showBack) {
      _flipController.reverse();
      setState(() => _showBack = false);
    } else {
      _flipController.forward();
      setState(() => _showBack = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Hero(
        tag: 'model-card-${widget.item.name}',
        createRectTween: (begin, end) =>
            MaterialRectCenterArcTween(begin: begin, end: end),
        flightShuttleBuilder: model3DCardFlipFlight,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, _) {
                final angle = _flipAnimation.value;
                final isFlipped = angle >= (math.pi / 2);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, -0.0011)
                    ..rotateY(angle),
                  child: isFlipped
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: ModelPerspectiveBack(
                            item: widget.item,
                            onFlipBack: _toggleFlip,
                          ),
                        )
                      : _buildFront(colors, isDark),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFront(NanoColors colors, bool isDark) {
    final item = widget.item;
    final cardContent = Material(
      color: isDark
          ? const Color(0xFF0F1523).withValues(alpha: 0.90)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isActive
              ? const Color(0xFF10B981)
              : colors.outlineVariant.withValues(alpha: 0.28),
          width: widget.isActive ? 1.5 : 1.0,
        ),
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
                  Model3DLogoBox(item: item, size: 66),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.company.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            ModelTagBadge(
                              label: item.typeTag,
                              color: colors.primary,
                            ),
                            if (item.isRecommendedForNano) ...[
                              const SizedBox(width: 4),
                              const ModelTagBadge(
                                label: 'Sugerido',
                                color: Color(0xFF10B981),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.name,
                          maxLines: 1,
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
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
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
                            // Muestra el borrado solo cuando existe un paquete instalado y una acción real.
                            if (item.installed && widget.onDelete != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Eliminar modelo descargado',
                                color: colors.error,
                                onPressed: widget.onDelete,
                              ),
                            IconButton(
                              icon: const Icon(Icons.flip_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Girar tarjeta 3D',
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
