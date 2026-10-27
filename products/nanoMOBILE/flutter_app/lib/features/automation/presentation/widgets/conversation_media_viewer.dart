// conversation_media_viewer.dart
//
// QUÉ HACE:
// Coordinador principal de visores multimedia (Fotos, PDFs, Videos y Navegador web).
//
// CÓMO FUNCIONA:
// - Delega el visor de fotos a ConversationPhotoViewer (pantalla completa, zoom, compartir).
// - Procesa e imprime documentos PDF con Printing.layoutPdf.
// - Abre enlaces externos o en el navegador in-app de Nano AI.
// - Lanza videos en el reproductor interactivo in-app o en ventana flotante.
//
// POR QUÉ:
// Respeta el principio de responsabilidad única (SRP), garantizando que este archivo
// permanezca estrictamente bajo el límite de 200 líneas de código.

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'conversation_inapp_player.dart';
import 'conversation_media_source.dart';
import 'conversation_photo_viewer.dart';
import 'conversation_pdf_viewer.dart';

export 'conversation_photo_viewer.dart';

/// Visor interactivo y despachador de medios para el Centro de Mensajería.
abstract final class ConversationMediaViewer {
  /// Despliega el visor de fotos en pantalla completa.
  static void showPhotoViewer(
    BuildContext context, {
    required String pathOrUrl,
    String? caption,
    Object? heroTag,
  }) {
    ConversationPhotoViewer.show(
      context,
      pathOrUrl: pathOrUrl,
      caption: caption,
      heroTag: heroTag,
    );
  }

  /// Abre un documento PDF mediante el visor nativo de impresión `Printing.layoutPdf`.
  static Future<void> openPdfDocument(
    BuildContext context, {
    required String pathOrUrl,
    String? title,
  }) async {
    await ConversationPdfViewer.show(
      context,
      pathOrUrl: pathOrUrl,
      title: title,
    );
  }

  /// Abre un enlace web o video en el navegador o aplicación externa.
  static Future<void> openExternalLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var rawUrl = url.trim();
    if (rawUrl.toLowerCase().startsWith('www.')) rawUrl = 'https://$rawUrl';
    final source = ConversationMediaSource(rawUrl);
    if (source.isLocal && !source.existsSync) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('El archivo ya no está disponible'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final uri = source.launchUri;
      if (uri == null) throw const FormatException('Ruta inválida');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: rawUrl));
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Enlace copiado al portapapeles'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Enlace copiado al portapapeles: $rawUrl'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Abre un video en el reproductor interactivo in-app.
  static Future<void> openVideo(
    BuildContext context,
    String urlOrPath, {
    String? youTubeId,
    String? title,
  }) async {
    final source = ConversationMediaSource(urlOrPath);
    if (source.isLocal && !source.existsSync) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('El video ya no está disponible'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ConversationInAppPlayer.showVideoPlayer(
      context,
      urlOrPath: urlOrPath,
      title: title,
      youTubeId: youTubeId,
      floating: source.isRemote || (youTubeId?.isNotEmpty ?? false),
    );
  }

  /// Abre un enlace web en el navegador in-app de Nano AI.
  static void openInAppWeb(BuildContext context, String url, {String? title}) {
    ConversationInAppPlayer.showWebBrowser(context, url: url, title: title);
  }
}
