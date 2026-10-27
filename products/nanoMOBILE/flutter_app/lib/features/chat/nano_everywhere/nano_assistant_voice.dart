import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../core/services/nano_runtime_api.dart';
import '../../automation/engine/voice/voice_runtime.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';

/// Dictado y lectura del búho usan la misma sesión de Nano en producción.
/// La voz prepara el borrador y nunca ejecuta una orden al reconocerla.
class NanoAssistantVoice with WidgetsBindingObserver {
  NanoAssistantVoice(
    this.current, {
    NanoRuntimeApi? api,
    VoiceSessionManager? session,
  }) : _api = api ?? NanoRuntimeApi.instance,
       _session = session {
    WidgetsBinding.instance.addObserver(this);
  }
  final NanoAiController Function() current;
  final NanoRuntimeApi _api;
  final VoiceSessionManager? _session;
  final Object _voiceOwner = Object();
  bool _capturing = false, _speaking = false, _disposed = false;
  int _generation = 0;

  /// Escucha una frase. Segunda pulsación detiene únicamente su propia captura;
  /// otro módulo que tome la sesión invalida el resultado antes de publicarlo.
  Future<void> toggle() async {
    if (_disposed) return;
    if (_capturing) {
      await stop();
      return;
    }
    final owner = current();
    if (owner.isBusy || owner.activity == NanoActivity.acting) return;
    await stopReading();
    _capturing = true;
    final token = ++_generation;
    owner.setListening(true);
    owner.reportStatus('Escuchando… Pulsa el micrófono para detener.');
    try {
      final session = _session;
      final text = session == null
          ? await _api.startVoiceRecognition().timeout(
              const Duration(seconds: 35),
            )
          : (await session.pushToTalk(owner: _voiceOwner))?.transcript;
      if (_disposed ||
          token != _generation ||
          !identical(owner, current()) ||
          (session != null && !session.isOwnedBy(_voiceOwner))) {
        return;
      }
      if (text == null || text.trim().isEmpty) {
        owner.reportStatus('No se reconoció texto. Puedes volver a dictar.');
      } else {
        owner.queueDictation(text.trim());
        owner.reportStatus(
          'Dictado preparado. Revisa la instrucción antes de ejecutar.',
        );
      }
    } on TimeoutException {
      await _releaseCapture();
      if (!_disposed && token == _generation) {
        owner.reportStatus('Dictado detenido por inactividad.');
      }
    } on Object {
      if (!_disposed && token == _generation) {
        owner.reportStatus('No se pudo usar el micrófono. Revisa su permiso.');
      }
    } finally {
      if (token == _generation) {
        _capturing = false;
        if (!_disposed &&
            identical(owner, current()) &&
            owner.activity == NanoActivity.listening) {
          owner.setListening(false);
        }
        await _releaseCapture();
      }
    }
  }

  /// Libera la captura del dueño actual; el adaptador directo solo se usa
  /// cuando no se inyectó la sesión compartida (por ejemplo, una vista aislada).
  Future<void> _releaseCapture() async {
    final session = _session;
    if (session == null) {
      await _api.cancelVoiceRecognition();
      return;
    }
    if (session.isOwnedBy(_voiceOwner)) await session.stop(owner: _voiceOwner);
  }

  /// Alterna lectura explícita. No interpreta su contenido como acciones.
  Future<void> read(String text) async {
    if (_speaking &&
        (_session?.isOwnedBy(_voiceOwner) ?? await _api.isSpeechActive())) {
      await stopReading();
    } else {
      await startReading(text);
    }
  }

  /// Entrada para Flutter y overlay nativo: devuelve aceptación, no fin de audio.
  Future<bool> startReading(String text) async {
    if (_disposed || text.trim().isEmpty || _capturing) return false;
    final session = _session;
    if (session == null) {
      _speaking = await _api.speak(text);
    } else {
      await session.respond(text, owner: _voiceOwner);
      _speaking =
          session.isOwnedBy(_voiceOwner) &&
          session.state != VoiceSessionState.idle;
    }
    if (!_speaking && !_disposed) {
      current().reportStatus('La lectura de voz no está disponible.');
    }
    return _speaking;
  }

  /// Nunca apaga una locución de otro dueño de la sesión compartida.
  Future<void> stopReading() async {
    if (!_speaking) return;
    _speaking = false;
    final session = _session;
    if (session == null) {
      await _api.stopSpeech();
      return;
    }
    if (session.isOwnedBy(_voiceOwner)) await session.stop(owner: _voiceOwner);
  }

  /// Invalida primero los resultados y después solicita liberar audio propio.
  Future<void> stop() async {
    ++_generation;
    if (_capturing) {
      _capturing = false;
      await _releaseCapture();
      if (!_disposed && current().activity == NanoActivity.listening) {
        current().setListening(false);
        current().reportStatus('Dictado detenido.');
      }
    }
    await stopReading();
  }

  /// El dictado Flutter no permanece abierto al abandonar primer plano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  /// No destruye la sesión global: solo el observador y operaciones de este búho.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stop());
  }
}
