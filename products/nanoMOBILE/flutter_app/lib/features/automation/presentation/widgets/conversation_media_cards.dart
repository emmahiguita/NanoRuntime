// conversation_media_cards.dart
//
// QUÉ HACE:
// Tarjetas de previsualización interactiva de imágenes y videos locales/remotos.
//
// CÓMO FUNCIONA:
// - Renderiza miniaturas de imágenes con Hero animation y apertura en visor a pantalla completa.
// - Renderiza tarjetas de video locales/remotos con botón táctil y apertura en reproductor in-app.
//
// POR QUÉ:
// Asegura una experiencia multimedia real en el chat respetando SOLID y el límite de 200 líneas.

library;

import 'package:flutter/material.dart';
import 'conversation_media_viewer.dart';
import 'conversation_media_source.dart';

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.9),
          ),
          child: Stack(
            children: [
              Hero(
                tag: tag,
                child: source.isLocal
                    ? file != null && file.existsSync()
                        ? Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ConversationFallbackTile(icon: Icons.broken_image_rounded, label: 'Foto no disponible'),
                          )
                        : const ConversationFallbackTile(icon: Icons.broken_image_rounded, label: 'Foto no disponible')
                    : Image.network(
                        source.value,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) => progress == null
                            ? child
                            : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)))),
                        errorBuilder: (_, __, ___) => const ConversationFallbackTile(icon: Icons.broken_image_rounded, label: 'Foto no disponible'),
                      ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text('Ver foto', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
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

/// Tarjeta de video interactiva con reproductor in-app y botón táctil.
class ConversationVideoCard extends StatelessWidget {
  final String urlOrPath;
  const ConversationVideoCard({super.key, required this.urlOrPath});

  @override
  Widget build(BuildContext context) {
    final fileName = ConversationMediaSource(urlOrPath).displayName;
    return GestureDetector(
      onTap: () => ConversationMediaViewer.openVideo(context, urlOrPath, title: fileName),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.40), width: 0.9),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.90),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName.isNotEmpty ? fileName : 'Video multimedia',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ondemand_video_rounded, color: Color(0xFF60A5FA), size: 12),
                      SizedBox(width: 4),
                      Text('Toca para reproducir', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile de fallback cuando un archivo no se puede cargar.
class ConversationFallbackTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const ConversationFallbackTile({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
