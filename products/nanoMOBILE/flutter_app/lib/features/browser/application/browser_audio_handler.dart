import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_webview_registry.dart';

/// Publica medios reales y dirige los controles a su WebView de origen.
/// BaseAudioHandler empieza en idle: abrir Nano no crea un reproductor.
class BrowserAudioHandler extends BaseAudioHandler {
  BrowserAudioHandler(ProviderContainer container) {
    // Cuando el registro libera un WebView, se retira su sesión y su handler JS.
    container.read(browserWebViewRegistryProvider).onMediaSourceRemoved =
        detachSource;
  }

  String? _sourceId;
  InAppWebViewController? _controller;
  int _commandGeneration = 0;

  /// Controlador vigente por fuente (pestaña o PiP). Sirve para descartar
  /// eventos de un WebView ya reemplazado o destruido.
  final Map<String, InAppWebViewController> _sources = {};

  /// El callback vive con el WebView conservado al salir del navegador.
  /// No depende del widget visible: las pausas siguen llegando desde Home.
  void attachSource(String sourceId, InAppWebViewController controller) {
    _sources[sourceId] = controller;
    controller.addJavaScriptHandler(
      handlerName: 'audioState',
      callback: (args) {
        // Solo el controlador registrado actualmente puede publicar estado.
        if (identical(_sources[sourceId], controller) &&
            args.isNotEmpty &&
            args.first is Map) {
          _update(sourceId, controller, args.first as Map);
        }
        return null;
      },
    );
  }

  /// Solo una fuente que reproduce puede tomar posesión de la sesión.
  /// Una pestaña silenciosa nunca sustituye el título de otra que suena.
  void _update(String sourceId, InAppWebViewController controller, Map data) {
    final playing = data['playing'] == true;
    if (sourceId != _sourceId && !playing) return;
    if (data['present'] != true || data['ended'] == true) {
      clearSource(sourceId);
      return;
    }
    // Cambiar de dueño invalida comandos en vuelo dirigidos a la fuente anterior.
    if (_sourceId != sourceId) ++_commandGeneration;
    _sourceId = sourceId;
    _controller = controller;
    final duration = _duration(data['duration']);
    final title = data['title']?.toString().trim() ?? '';
    final item = MediaItem(
      id: '$sourceId:${data['mediaId'] ?? ''}',
      title: title.isEmpty ? 'Audio del navegador' : title,
      artist: data['artist']?.toString(),
      duration: duration > Duration.zero ? duration : null,
      artUri: _artwork(data['artwork']),
    );
    if (mediaItem.value != item) mediaItem.add(item);
    final controls = [
      if (data['previous'] == true) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (data['next'] == true) MediaControl.skipToNext,
      MediaControl.stop,
    ];
    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        androidCompactActionIndices: List.generate(
          controls.length.clamp(1, 3),
          (i) => i,
        ),
        systemActions: {if (duration > Duration.zero) MediaAction.seek},
        playing: playing,
        processingState: data['buffering'] == true && playing
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        updatePosition: _duration(data['position']),
        speed: _positiveNumber(data['speed'], 1),
      ),
    );
  }

  /// Cerrar/navegar la fuente retira la sesión y la referencia nativa.
  void clearSource(String sourceId) {
    if (_sourceId != sourceId) return;
    ++_commandGeneration;
    _sourceId = null;
    _controller = null;
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
    mediaItem.add(null);
  }

  /// Al destruir la vista también invalida callbacks que lleguen tarde.
  void detachSource(String sourceId) {
    _sources
        .remove(sourceId)
        ?.removeJavaScriptHandler(handlerName: 'audioState');
    clearSource(sourceId);
  }

  /// El evento DOM confirma el resultado; no anuncia playing si el sitio
  /// rechaza play(). Cada comando apunta al mismo medio que informó la sesión.
  Future<void> _command(String action, [double? position]) async {
    final controller = _controller;
    final source = _sourceId;
    final generation = _commandGeneration;
    if (controller == null || source == null) return;
    try {
      if (action == 'play') await controller.resume();
      if (generation != _commandGeneration) return;
      await controller.evaluateJavascript(
        source:
            'window.__nanoMediaBridge?.command(${jsonEncode(action)}, ${jsonEncode(position)});',
      );
    } catch (error) {
      debugPrint('[browser-audio] Acción $action falló: $error');
      if (generation == _commandGeneration) clearSource(source);
    }
  }

  @override
  Future<void> play() => _command('play');
  @override
  Future<void> pause() => _command('pause');
  @override
  Future<void> seek(Duration position) =>
      _command('seek', position.inMilliseconds / 1000);
  @override
  Future<void> skipToNext() => _command('next');
  @override
  Future<void> skipToPrevious() => _command('previous');

  /// Detener desde Android pausa el elemento y elimina la notificación.
  @override
  Future<void> stop() async {
    final source = _sourceId;
    await _command('pause');
    if (source != null) clearSource(source);
  }

  @override
  Future<void> onTaskRemoved() => stop();

  /// Los valores externos del sitio se validan antes de enviarlos a Android.
  static double _positiveNumber(Object? value, double fallback) =>
      value is num && value.isFinite && value >= 0
      ? value.toDouble()
      : fallback;
  static Duration _duration(Object? value) => Duration(
    milliseconds: (_positiveNumber(value, 0).clamp(0, 31536000) * 1000).round(),
  );
  static Uri? _artwork(Object? value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
  }
}
