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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'conversation_inapp_player.dart';
import 'conversation_photo_viewer.dart';

export 'conversation_photo_viewer.dart';

/// Visor interactivo y despachador de medios para el Centro de Mensajería.
abstract final class ConversationMediaViewer {
  /// Despliega el visor de fotos en pantalla completa.
  static void showPhotoViewer(
    BuildContext context, {
    required String pathOrUrl,
    String? caption,
  }) {
    ConversationPhotoViewer.show(context, pathOrUrl: pathOrUrl, caption: caption);
  }

  /// Abre un documento PDF mediante el visor nativo de impresión `Printing.layoutPdf`.
  static Future<void> openPdfDocument(
    BuildContext context, {
    required String pathOrUrl,
    String? title,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cleanPath = pathOrUrl.startsWith('file://') ? pathOrUrl.replaceFirst('file://', '') : pathOrUrl;
    final isLocal = !cleanPath.startsWith('http://') && !cleanPath.startsWith('https://');
    final fileName = title ?? cleanPath.split(Platform.pathSeparator).last.split('/').last;

    try {
      Uint8List? bytes;
      if (isLocal) {
        final file = File(cleanPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Descargando PDF para visualización...'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        final res = await http.get(Uri.parse(cleanPath));
        if (res.statusCode == 200) bytes = res.bodyBytes;
      }

      if (bytes != null && bytes.isNotEmpty) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes!,
          name: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
        );
      } else if (context.mounted) {
        await openExternalLink(context, cleanPath);
      }
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Abre un enlace web o video en el navegador o aplicación externa.
  static Future<void> openExternalLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var rawUrl = url.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://') && !rawUrl.startsWith('file://')) {
      rawUrl = 'https://$rawUrl';
    }

    try {
      final uri = Uri.parse(rawUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: rawUrl));
        messenger?.showSnackBar(
          const SnackBar(content: Text('Enlace copiado al portapapeles'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      messenger?.showSnackBar(
        SnackBar(content: Text('Enlace copiado al portapapeles: $rawUrl'), behavior: SnackBarBehavior.floating),
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
    ConversationInAppPlayer.showVideoPlayer(
      context,
      urlOrPath: urlOrPath,
      title: title,
      youTubeId: youTubeId,
    );
  }

  /// Abre un enlace web en el navegador in-app de Nano AI.
  static void openInAppWeb(BuildContext context, String url, {String? title}) {
    ConversationInAppPlayer.showWebBrowser(context, url: url, title: title);
  }
}
