import 'package:flutter/material.dart';
import 'conversation_media_viewer.dart';
import 'conversation_media_source.dart';

/// Tarjeta de video interactiva con reproductor in-app y botón táctil.
class ConversationVideoCard extends StatelessWidget {
  final String urlOrPath;
  const ConversationVideoCard({super.key, required this.urlOrPath});

  @override
  Widget build(BuildContext context) {
    final fileName = ConversationMediaSource(urlOrPath).displayName;
    return GestureDetector(
      onTap: () => ConversationMediaViewer.openVideo(
        context,
        urlOrPath,
        title: fileName,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.40),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
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
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName.isNotEmpty ? fileName : 'Video multimedia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ondemand_video_rounded,
                        color: Color(0xFF60A5FA),
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Toca para reproducir',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
