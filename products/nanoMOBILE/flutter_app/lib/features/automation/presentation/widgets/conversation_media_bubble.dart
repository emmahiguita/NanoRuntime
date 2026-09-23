// conversation_media_bubble.dart
//
// QUÉ HACE:
// Renderiza el contenido visual enriquecido de una burbuja de chat: fotos reales, videos reales,
// reproductor interactivo de notas de voz, PDFs, enlaces web y texto formateado.
//
// CÓMO FUNCIONA:
// - Analiza el mensaje mediante ParsedMediaMessage.
// - Si es notificación de foto o video, resuelve el archivo real en disco con WhatsAppMediaResolver.
// - Renderiza componentes modulares (SRP) según el tipo de medio detectado.
//
// POR QUÉ:
// Soluciona el problema de textos simulados ("📷 Envió una foto.") mostrando fotos y videos reales,
// respetando SOLID y la regla estricta de < 200 líneas por archivo.

library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'parsed_media_message.dart';
import 'conversation_media_cards.dart';
import 'conversation_youtube_card.dart';
import 'conversation_link_card.dart';
import 'conversation_doc_card.dart';
import 'voice_note_player_card.dart';
import 'view_once_media_card.dart';
import 'whatsapp_media_resolver.dart';
import 'conversation_media_viewer.dart';

export 'parsed_media_message.dart';
export 'conversation_media_cards.dart';
export 'conversation_youtube_card.dart';
export 'conversation_link_card.dart';
export 'conversation_doc_card.dart';

/// Renderiza el contenido multimedia y textual de un mensaje de chat.
class ConversationMediaBubble extends StatelessWidget {
  final String text;
  final bool isInbound;
  final AutomationVisualPalette visual;
  final int? timestampMs;
  static const List<String> _sfFallback = ['.SF UI Text', 'Inter', 'Roboto'];

  const ConversationMediaBubble({
    super.key,
    required this.text,
    required this.isInbound,
    required this.visual,
    this.timestampMs,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = ParsedMediaMessage.parse(text);

    return Column(
      crossAxisAlignment: isInbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Mensajes para ver una sola vez (View Once)
        if (parsed.isViewOnce) ...[
          ViewOnceMediaCard(mediaPath: parsed.viewOncePath, isVideo: parsed.isViewOnceVideo),
          const SizedBox(height: 6),
        ],

        // 2. Fotos e imágenes explícitas
        for (final img in parsed.images) ...[
          ConversationImageCard(pathOrUrl: img),
          const SizedBox(height: 6),
        ],

        // 3. Notificación de Foto (resuelve archivo real en WhatsApp si no vino explícito)
        if (parsed.isPhotoNotification && parsed.images.isEmpty && !parsed.isViewOnce) ...[
          FutureBuilder<String?>(
            future: WhatsAppMediaResolver.findRecentWhatsAppImage(referenceTimestampMs: timestampMs),
            builder: (ctx, snapshot) {
              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                return ConversationImageCard(pathOrUrl: snapshot.data!);
              }
              return ConversationMediaBadge(
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF00FF88),
                label: 'Foto de WhatsApp',
                description: 'Toca para abrir visor',
                onTap: () async {
                  final img = await WhatsAppMediaResolver.findRecentWhatsAppImage(referenceTimestampMs: timestampMs);
                  if (img != null && context.mounted) {
                    ConversationMediaViewer.showPhotoViewer(context, pathOrUrl: img);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 6),
        ],

        // 4. Videos explícitos o YouTube
        for (final ytId in parsed.youTubeIds) ...[
          ConversationYouTubeCard(videoId: ytId),
          const SizedBox(height: 6),
        ],
        for (final vid in parsed.videos.where((v) => !parsed.youTubeIds.any((id) => v.contains(id)))) ...[
          ConversationVideoCard(urlOrPath: vid),
          const SizedBox(height: 6),
        ],

        // 5. Notificación de Video (resuelve archivo real en WhatsApp)
        if (parsed.isVideoNotification && parsed.videos.isEmpty && !parsed.isViewOnce) ...[
          FutureBuilder<String?>(
            future: WhatsAppMediaResolver.findRecentWhatsAppVideo(referenceTimestampMs: timestampMs),
            builder: (ctx, snapshot) {
              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                return ConversationVideoCard(urlOrPath: snapshot.data!);
              }
              return ConversationMediaBadge(
                icon: Icons.videocam_rounded,
                color: const Color(0xFF60A5FA),
                label: 'Video de WhatsApp',
                description: 'Toca para reproducir',
                onTap: () async {
                  final vid = await WhatsAppMediaResolver.findRecentWhatsAppVideo(referenceTimestampMs: timestampMs);
                  if (vid != null && context.mounted) {
                    ConversationMediaViewer.openVideo(context, vid);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 6),
        ],

        // 6. Documentos PDF
        for (final pdf in parsed.pdfs) ...[
          ConversationPdfCard(pathOrUrl: pdf),
          const SizedBox(height: 6),
        ],

        // 7. Audios y notas de voz
        for (final audio in parsed.audios) ...[
          VoiceNotePlayerCard(audioPathOrUrl: audio, isInbound: isInbound),
          const SizedBox(height: 6),
        ],
        if (parsed.isAudioNotification && parsed.audios.isEmpty) ...[
          FutureBuilder<String?>(
            future: WhatsAppMediaResolver.findRecentWhatsAppVoiceNote(referenceTimestampMs: timestampMs),
            builder: (ctx, snapshot) {
              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                return VoiceNotePlayerCard(audioPathOrUrl: snapshot.data!, isInbound: isInbound);
              }
              return const ConversationMediaBadge(
                icon: Icons.mic_rounded,
                color: Color(0xFFF59E0B),
                label: 'Nota de voz de WhatsApp',
                description: 'Audio recibido',
              );
            },
          ),
          const SizedBox(height: 6),
        ],

        // 8. Enlaces Web (Links)
        for (final link in parsed.links) ...[
          ConversationLinkCard(url: link),
          const SizedBox(height: 6),
        ],

        // 9. Otros archivos adjuntos
        for (final doc in parsed.otherFiles) ...[
          ConversationFileCard(pathOrUrl: doc),
          const SizedBox(height: 6),
        ],

        // 10. Texto limpio complementario
        if (parsed.cleanText.isNotEmpty &&
            !parsed.isPhotoNotification &&
            !parsed.isVideoNotification &&
            !parsed.isAudioNotification)
          Text(
            parsed.cleanText,
            style: TextStyle(
              color: isInbound ? visual.text : Colors.white,
              fontFamily: 'Inter',
              fontFamilyFallback: _sfFallback,
              fontSize: 14,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
      ],
    );
  }
}
