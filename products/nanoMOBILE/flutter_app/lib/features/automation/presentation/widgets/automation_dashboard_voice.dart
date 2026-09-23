/// AUTOMATION-DASHBOARD-VOICE — Lógica de voz y observación de pantalla.
///
/// QUÉ HACE:
/// Gestiona las órdenes por voz (push-to-talk), conversación continua,
/// conmutación de salida de audio y lectura contextual de la pantalla activa.
///
/// CÓMO FUNCIONA:
/// Se integra con [VoiceSessionManager] de Nano y [currentSituationSourceProvider].
///
/// POR QUÉ:
/// Modulariza las capacidades sensoriales manteniendo el archivo principal < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../engine/perception/current_situation.dart';
import '../../engine/voice/voice_runtime.dart';

class AutomationVoiceHandler {
  static String describeSituation(CurrentSituation situation) {
    final surface = switch (situation.surfaceKind) {
      CurrentSurfaceKind.dialog => 'diálogo',
      CurrentSurfaceKind.search => 'búsqueda',
      CurrentSurfaceKind.editable => 'campo editable',
      CurrentSurfaceKind.picker => 'selección',
      CurrentSurfaceKind.collection => 'lista',
      CurrentSurfaceKind.mediaViewer => 'visor multimedia',
      CurrentSurfaceKind.content => 'contenido',
      CurrentSurfaceKind.unknown => 'superficie sin clasificar',
    };
    final completeness = situation.isComplete ? '' : ' · lectura parcial';
    return 'Ojos activos · $surface · ${situation.packageName}$completeness';
  }

  static Future<void> toggleVoiceOutput({
    required SettingsNotifier settingsNotifier,
    required bool currentEnabled,
    required ValueChanged<String> onFeedback,
  }) async {
    await settingsNotifier.setVoiceEnabled(!currentEnabled);
    onFeedback(
      currentEnabled
          ? 'Audio de Nano apagado · responderá solo con texto.'
          : 'Audio de Nano encendido.',
    );
  }
}
