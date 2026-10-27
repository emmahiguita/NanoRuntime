import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'browser_audio_handler.dart';

/// Registra controles multimedia en Android sin retrasar el primer frame.
Future<void> initializeBrowserAudioService(BrowserAudioHandler handler) async {
  try {
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'dev.nanoai.channel.audio',
        androidNotificationChannelName: 'Reproducción del navegador',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } on Object catch (error, stackTrace) {
    // Si Android rechaza controles en segundo plano, la interfaz sigue usable.
    debugPrint('[audio-service] No se pudo iniciar: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
