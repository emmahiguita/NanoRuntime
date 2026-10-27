part of 'business_store_media_view.dart';

/// Decodifica imágenes de forma asíncrona con un tamaño de caché acotado.
/// Un vídeo adjunto no promete reproducción ni resolución sin metadatos reales.
class _StoreMediaImage extends StatelessWidget {
  const _StoreMediaImage({
    required this.path,
    required this.fit,
    required this.isVideo,
    required this.showVideoLabel,
  });
  final String path;
  final BoxFit fit;
  final bool isVideo, showVideoLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
      final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context)).round().clamp(128, 1600);
      final small = width < 100 || constraints.maxHeight < 80;
      Widget placeholder(String label, IconData icon) => Semantics(
        label: label,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: small ? 24 : 32, color: colors.onSurfaceVariant),
                if (!small && (!isVideo || showVideoLabel)) ...[
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      Widget content;
      if (isVideo) {
        content = placeholder('Vídeo adjunto', Icons.videocam_outlined);
      } else if (path.isEmpty) {
        content = placeholder('Sin imagen', Icons.image_outlined);
      } else if (path.startsWith('assets/')) {
        content = Image.asset(
          path,
          fit: fit,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stack) => placeholder('Imagen no disponible', Icons.broken_image_outlined),
        );
      } else {
        content = Image.file(
          File(path),
          fit: fit,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stack) => placeholder('Imagen no disponible', Icons.broken_image_outlined),
        );
      }
      return ColoredBox(color: colors.surfaceContainerHighest.withValues(alpha: .3), child: content);
    },
  );
}
