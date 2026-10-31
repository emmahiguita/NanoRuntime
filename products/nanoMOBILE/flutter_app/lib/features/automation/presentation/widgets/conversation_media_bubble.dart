import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'parsed_media_message.dart';
import 'conversation_media_cards.dart';
import 'conversation_youtube_card.dart';
import 'conversation_link_card.dart';
import 'conversation_doc_card.dart';
import 'voice_note_player_card.dart';
import 'view_once_media_card.dart';
import 'unbound_whatsapp_media_card.dart';
import 'whatsapp_media_resolver.dart';

export 'parsed_media_message.dart';
export 'conversation_media_cards.dart';
export 'conversation_youtube_card.dart';
export 'conversation_link_card.dart';
export 'conversation_doc_card.dart';

/// Presenta archivos multimedia enriquecidos y texto limpio del mensaje.
/// Resuelve notas de voz, fotos y videos locales cuando llegan como notificaciones.
class ConversationMediaBubble extends StatelessWidget {
  final String text;
  final bool isInbound;
  final AutomationVisualPalette visual;
  final int? timestampMs;
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
    final tag = '${timestampMs ?? 0}_${text.hashCode}';
    return Column(
      crossAxisAlignment: isInbound
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Once conserva su tratamiento existente; no se recupera desde carpetas.
        if (parsed.isViewOnce)
          ViewOnceMediaCard(
            mediaPath: parsed.viewOncePath,
            isVideo: parsed.isViewOnceVideo,
          ),
        for (final (index, image) in parsed.images.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ConversationImageCard(
              pathOrUrl: image,
              heroTag: 'media_photo_${tag}_$index',
            ),
          ),
        if (parsed.isPhotoNotification &&
            parsed.images.isEmpty &&
            !parsed.isViewOnce)
          FutureBuilder<String?>(
            future: WhatsAppMediaResolver.findRecentWhatsAppImage(
              referenceTimestampMs: timestampMs,
            ),
            builder: (ctx, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ConversationImageCard(
                    pathOrUrl: snapshot.data!,
                    heroTag: 'media_photo_${tag}_0',
                  ),
                );
              }
              return const UnboundWhatsAppMediaCard(
                label: 'Foto',
                icon: Icons.photo_outlined,
              );
            },
          ),
        for (final id in parsed.youTubeIds)
          ConversationYouTubeCard(videoId: id),
        for (final video in parsed.videos.where(
          (v) => !parsed.youTubeIds.any(v.contains),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ConversationVideoCard(urlOrPath: video),
          ),
        if (parsed.isVideoNotification &&
            parsed.videos.isEmpty &&
            !parsed.isViewOnce)
          FutureBuilder<String?>(
            future: WhatsAppMediaResolver.findRecentWhatsAppVideo(
              referenceTimestampMs: timestampMs,
            ),
            builder: (ctx, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ConversationVideoCard(urlOrPath: snapshot.data!),
                );
              }
              return const UnboundWhatsAppMediaCard(
                label: 'Vídeo',
                icon: Icons.video_file_outlined,
              );
            },
          ),
        for (final pdf in parsed.pdfs) ConversationPdfCard(pathOrUrl: pdf),
        for (final audio in parsed.audios)
          VoiceNotePlayerCard(audioPathOrUrl: audio, isInbound: isInbound),
        if (parsed.isAudioNotification &&
            parsed.audios.isEmpty &&
            !parsed.isViewOnce)
          FutureBuilder<String?>(
            future: WhatsAppMediaResolver.findRecentWhatsAppVoiceNote(
              referenceTimestampMs: timestampMs,
            ),
            builder: (ctx, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return VoiceNotePlayerCard(
                  audioPathOrUrl: snapshot.data!,
                  isInbound: isInbound,
                );
              }
              return const UnboundWhatsAppMediaCard(
                label: 'Audio',
                icon: Icons.audio_file_outlined,
              );
            },
          ),
        for (final link in parsed.links) ConversationLinkCard(url: link),
        for (final file in parsed.otherFiles)
          ConversationFileCard(pathOrUrl: file),
        if (parsed.cleanText.isNotEmpty &&
            !parsed.isPhotoNotification &&
            !parsed.isVideoNotification &&
            !parsed.isAudioNotification)
          Text(
            parsed.cleanText,
            style: TextStyle(
              color: isInbound ? visual.text : visual.onAccent,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['.SF UI Text', 'Roboto'],
              fontSize: 14,
              height: 1.35,
              letterSpacing: -.2,
            ),
          ),
      ],
    );
  }
}
