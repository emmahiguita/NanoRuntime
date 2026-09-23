// conversation_youtube_card.dart
//
// QUÉ HACE:
// Tarjeta interactiva para videos de YouTube y badges genéricos de medios.
//
// CÓMO FUNCIONA:
// - Renderiza la miniatura de alta resolución de YouTube con botón play.
// - Al tocar abre el reproductor in-app o en ventana flotante Picture-in-Picture.
//
// POR QUÉ:
// Responsabilidad única (SRP) para componentes de video web y badges, estrictamente < 200 líneas.

library;

import 'package:flutter/material.dart';
import 'conversation_media_viewer.dart';

/// Tarjeta de video YouTube con miniatura de alta resolución y reproductor in-app.
class ConversationYouTubeCard extends StatelessWidget {
  final String videoId;
  const ConversationYouTubeCard({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final thumb = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    final url = 'https://www.youtube.com/watch?v=$videoId';

    return GestureDetector(
      onTap: () => ConversationMediaViewer.openVideo(context, url, youTubeId: videoId, title: 'YouTube Video'),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 180, maxWidth: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.network(
                thumb,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: const Color(0xFF1E293B),
                  child: const Center(child: Icon(Icons.smart_display_rounded, color: Colors.redAccent, size: 48)),
                ),
              ),
              Container(color: Colors.black.withValues(alpha: 0.35)),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.90), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
              Positioned(
                bottom: 8,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_in_picture_alt_rounded, color: Colors.redAccent, size: 12),
                      SizedBox(width: 4),
                      Text('Ventana Flotante', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
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

/// Badge compacto de medio recibido en notificación de WhatsApp.
class ConversationMediaBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String description;
  final VoidCallback? onTap;

  const ConversationMediaBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
