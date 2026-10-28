// model_detail_quick_actions.dart — Barra de 4 acciones rápidas en la ficha técnica.
// QUÉ HACE: Renderiza [Descargar/Instalado], [Favoritos], [Comparar] y [Compartir].
// CÓMO FUNCIONA: Botones verticales con icono y etiqueta corta, micro-interacciones táctiles.
// POR QUÉ: Permite interactuar con el modelo de forma inmediata idéntico al diseño de referencia (< 120 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class ModelDetailQuickActions extends StatelessWidget {
  final bool isInstalled;
  final bool isDownloading;
  final bool isFavorite;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onCompare;
  final VoidCallback? onShare;

  const ModelDetailQuickActions({
    super.key,
    required this.isInstalled,
    required this.isDownloading,
    this.isFavorite = false,
    this.onDownload,
    this.onCancel,
    this.onDelete,
    this.onToggleFavorite,
    this.onCompare,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final primaryAction = isDownloading
        ? onCancel
        : (isInstalled ? onDelete : onDownload);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (primaryAction != null)
            _ActionButton(
              label: isDownloading
                  ? 'Cancelar'
                  : (isInstalled ? 'Eliminar' : 'Descargar'),
              icon: isInstalled
                  ? Icons.delete_outline_rounded
                  : (isDownloading
                        ? Icons.close_rounded
                        : Icons.download_outlined),
              color: isInstalled ? const Color(0xFF10B981) : colors.primary,
              onTap: primaryAction,
            ),
          if (onToggleFavorite != null)
            _ActionButton(
              label: isFavorite ? 'Favorito' : 'Favoritos',
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              color: isFavorite
                  ? const Color(0xFFF43F5E)
                  : colors.onSurfaceVariant,
              onTap: onToggleFavorite,
            ),
          if (onCompare != null)
            _ActionButton(
              label: 'Comparar',
              icon: Icons.bar_chart_rounded,
              color: colors.onSurfaceVariant,
              onTap: onCompare,
            ),
          if (onShare != null)
            _ActionButton(
              label: 'Compartir',
              icon: Icons.share_outlined,
              color: colors.onSurfaceVariant,
              onTap: onShare,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NanoRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
