// view_once_media_card.dart
// 
// QUÉ HACE:
// Tarjeta visual para mensajes de WhatsApp de "Ver una sola vez" (View Once).
// 
// CÓMO FUNCIONA:
// - Detecta si la notificación contenía una foto o video efímero guardado en caché antes de ser destruido.
// - Renderiza un distintivo verde esmeralda con insignia (1) y botón para abrir en visor completo
//   (foto interactiva o video en ventana flotante).
// 
// POR QUÉ:
// WhatsApp elimina estos mensajes tras abrirlos; NanoAI los rescata en segundo plano y los
// presenta sin romper la privacidad ni exceder el límite de 200 líneas de código limpio.

import 'dart:io';
import 'package:flutter/material.dart';
import 'conversation_media_viewer.dart';
import 'whatsapp_media_resolver.dart';

/// Tarjeta para visualizar mensajes de WhatsApp marcados como "Ver una sola vez" (View Once).
class ViewOnceMediaCard extends StatelessWidget {
  final String? mediaPath;
  final bool isVideo;

  const ViewOnceMediaCard({super.key, this.mediaPath, this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    final hasValidPath = mediaPath != null && mediaPath!.trim().isNotEmpty;
    final file = hasValidPath ? File(mediaPath!.replaceFirst('file://', '')) : null;
    final fileExists = file?.existsSync() ?? false;

    return Container(
      constraints: const BoxConstraints(maxWidth: 290),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileExists && file != null && !isVideo)
              GestureDetector(
                onTap: () => ConversationMediaViewer.showPhotoViewer(context, pathOrUrl: file.path),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallback()),
                    ),
                    Positioned(top: 8, right: 8, child: _buildBadgeHeader()),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: Row(
                  children: [
                    _buildCircledBadge(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVideo ? 'Video para ver una vez' : 'Foto para ver una vez',
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          const Text('Preservado por NanoAI', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: InkWell(
                onTap: () => _handleOpenMedia(context, file, fileExists),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45), width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isVideo ? Icons.play_circle_fill_rounded : Icons.visibility_rounded, color: const Color(0xFF34D399), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isVideo ? 'Reproducir (Ventana flotante)' : 'Ver foto preservada',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircledBadge() => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF10B981),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: const Center(
          child: Text('1', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, height: 1.0)),
        ),
      );

  Widget _buildBadgeHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981), width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.looks_one_rounded, color: Color(0xFF34D399), size: 14),
            SizedBox(width: 4),
            Text('Ver una vez', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildFallback() => Container(
        height: 90,
        color: const Color(0xFF064E3B).withValues(alpha: 0.5),
        child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF34D399), size: 30)),
      );

  Future<void> _handleOpenMedia(BuildContext context, File? file, bool fileExists) async {
    if (fileExists && file != null) {
      if (isVideo) {
        ConversationMediaViewer.openVideo(context, file.path, title: 'Video Ver Una Vez');
      } else {
        ConversationMediaViewer.showPhotoViewer(context, pathOrUrl: file.path);
      }
      return;
    }
    if (isVideo) {
      final vid = await WhatsAppMediaResolver.findRecentWhatsAppVideo();
      if (vid != null && context.mounted) {
        ConversationMediaViewer.openVideo(context, vid, title: 'Video Ver Una Vez');
      }
    } else {
      final img = await WhatsAppMediaResolver.findRecentWhatsAppImage();
      if (img != null && context.mounted) {
        ConversationMediaViewer.showPhotoViewer(context, pathOrUrl: img);
      }
    }
  }
}
