import 'package:flutter/material.dart';
import 'conversation_media_viewer.dart';
import 'conversation_media_source.dart';
import 'conversation_fallback_tile.dart';

/// Tarjeta de previsualización de imagen con soporte interactivo a pantalla completa.
class ConversationImageCard extends StatelessWidget {
  final String pathOrUrl;
  final Object? heroTag;
  const ConversationImageCard({
    super.key,
    required this.pathOrUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final source = ConversationMediaSource(pathOrUrl);
    final file = source.localFile;
    final tag = heroTag ?? 'media_photo_$pathOrUrl';

    return GestureDetector(
      onTap: () => ConversationMediaViewer.showPhotoViewer(
        context,
        pathOrUrl: pathOrUrl,
        heroTag: tag,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 220, minWidth: 160),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.9,
            ),
          ),
          child: Stack(
            children: [
              Hero(
                tag: tag,
                child: source.isLocal
                    ? file != null
                          ? Image.file(
                              file,
                              // Decodifica solo tamaño de miniatura; el visor abre el original.
                              cacheWidth: 480,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ConversationFallbackTile(
                                    icon: Icons.broken_image_rounded,
                                    label: 'Foto no disponible',
                                  ),
                            )
                          : const ConversationFallbackTile(
                              icon: Icons.broken_image_rounded,
                              label: 'Foto no disponible',
                            )
                    : Image.network(
                        source.value,
                        cacheWidth: 480,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) =>
                            progress == null
                            ? child
                            : const SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00FF88),
                                  ),
                                ),
                              ),
                        errorBuilder: (_, __, ___) =>
                            const ConversationFallbackTile(
                              icon: Icons.broken_image_rounded,
                              label: 'Foto no disponible',
                            ),
                      ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.zoom_in_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Ver foto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
