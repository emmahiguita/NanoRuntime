// conversation_inapp_player.dart
//
// QUÉ HACE:
// Coordinador para reproducir videos (YouTube, MP4, clips locales) y abrir páginas web in-app.
//
// CÓMO FUNCIONA:
// - Despacha la reproducción a FloatingVideoController (PiP) o a VideoPlayerSheet.
// - Despacha la previsualización web a WebBrowserSheet.
//
// POR QUÉ:
// Aplica el principio de responsabilidad única (SRP), manteniendo el archivo bajo 60 líneas.

import 'package:flutter/material.dart';
import 'floating_video_overlay.dart';
import 'conversation_video_sheet.dart';
import 'conversation_web_sheet.dart';

abstract final class ConversationInAppPlayer {
  /// Despliega el reproductor de video en modal o en ventana flotante PiP.
  static void showVideoPlayer(
    BuildContext context, {
    required String urlOrPath,
    String? title,
    String? youTubeId,
    bool floating = true,
  }) {
    if (floating) {
      FloatingVideoController.instance.show(
        context,
        videoUrl: urlOrPath,
        title: title,
        youTubeId: youTubeId,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoPlayerSheet(
        urlOrPath: urlOrPath,
        title: title,
        youTubeId: youTubeId,
      ),
    );
  }

  /// Despliega el navegador web in-app en panel deslizable.
  static void showWebBrowser(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WebBrowserSheet(url: url, title: title),
    );
  }
}
