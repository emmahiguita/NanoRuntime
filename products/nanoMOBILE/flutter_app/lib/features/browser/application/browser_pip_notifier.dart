import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/browser_pip_model.dart';
import '../infrastructure/browser_scripts.dart';

/// Coordina una transferencia explícita entre el WebView de la pestaña y el
/// reproductor PiP visible. La fuente se pausa antes de montar el destino para
/// impedir audio duplicado y nunca se falsea la visibilidad de la página.
class BrowserPipNotifier extends StateNotifier<BrowserPipState> {
  BrowserPipNotifier() : super(const BrowserPipState()) {
    _systemPipChannel.setMethodCallHandler(_handleNativeCallback);
  }

  static const MethodChannel _systemPipChannel = MethodChannel(
    'com.nanoai/browser_pip',
  );

  InAppWebViewController? _sourceController;
  InAppWebViewController? _pipController;

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method != 'pipModeChanged') return;
    final active = call.arguments == true;
    state = state.copyWith(isSystemPip: active);
  }

  /// Registra la pestaña fuente actualmente visible. No reemplaza al
  /// controlador del reproductor flotante.
  void attachController(InAppWebViewController? controller) {
    _sourceController = controller;
  }

  void attachPipController(InAppWebViewController? controller) {
    _pipController = controller;
  }

  /// Mueve la reproducción al PiP. Devuelve true cuando se encontró un medio
  /// HTML y se pudo conservar su posición/estado.
  Future<bool> activatePip({
    required String tabId,
    required String url,
    required String title,
    InAppWebViewController? controller,
  }) async {
    _sourceController = controller ?? _sourceController;
    final media = await _readMediaState(_sourceController);
    if (media != null) {
      try {
        await _sourceController?.evaluateJavascript(
          source: BrowserScripts.pauseMediaScript,
        );
      } catch (_) {}
    }

    state = state.copyWith(
      isActive: true,
      isCompact: false,
      isMaximized: false,
      activeTabId: tabId,
      url: url,
      title: title,
      isPlaying: media?.wasPlaying ?? false,
      resumePositionSeconds: media?.positionSeconds ?? 0,
      transferPending: media != null,
    );
    return media != null;
  }

  /// Se invoca cuando el WebView PiP terminó de cargar. El destino siempre es
  /// visible; algunos sitios pueden exigir un toque adicional para reproducir.
  Future<void> synchronizePipPlayback() async {
    final controller = _pipController;
    if (controller == null || !state.isActive) return;
    try {
      await controller.evaluateJavascript(
        source: BrowserScripts.restoreVisibleMediaScript(
          positionSeconds: state.resumePositionSeconds,
          shouldPlay: state.isPlaying,
        ),
      );
    } finally {
      state = state.copyWith(transferPending: false);
    }
  }

  Future<void> deactivatePip() async {
    try {
      await _pipController?.evaluateJavascript(
        source: BrowserScripts.pauseMediaScript,
      );
    } catch (_) {}
    _pipController = null;
    state = state.copyWith(
      isActive: false,
      isPlaying: false,
      isSystemPip: false,
      isMaximized: false,
      transferPending: false,
    );
  }

  void toggleCompact() {
    // Se conserva por compatibilidad con llamadas antiguas, pero el reproductor
    // ya no puede ocultarse en una píldora de 1 px.
    state = state.copyWith(isCompact: false);
  }

  void toggleMaximized() {
    state = state.copyWith(isMaximized: !state.isMaximized);
  }

  void updatePosition(Offset newPosition, Size screenSize) {
    final width = state.size.width;
    final height = state.size.height;
    final x = newPosition.dx.clamp(
      8.0,
      (screenSize.width - width - 8).clamp(8.0, double.infinity),
    );
    final y = newPosition.dy.clamp(
      40.0,
      (screenSize.height - height - 40).clamp(40.0, double.infinity),
    );
    state = state.copyWith(position: Offset(x, y));
  }

  void updatePositionRaw(Offset newPosition, Size screenSize) {
    final x = newPosition.dx.clamp(
      0.0,
      (screenSize.width - state.size.width).clamp(0.0, double.infinity),
    );
    final y = newPosition.dy.clamp(
      0.0,
      (screenSize.height - state.size.height).clamp(0.0, double.infinity),
    );
    state = state.copyWith(position: Offset(x, y));
  }

  void resizePip(Size requested, Size screenSize) {
    final maxWidth = (screenSize.width - 16).clamp(240.0, double.infinity);
    final maxHeight = (screenSize.height - 80).clamp(220.0, double.infinity);
    final width = requested.width.clamp(240.0, maxWidth);
    final height = requested.height.clamp(220.0, maxHeight);
    state = state.copyWith(size: Size(width, height));
    updatePosition(state.position, screenSize);
  }

  void cyclePipSize() {
    final next = state.size.width < 300
        ? const Size(320, 250)
        : state.size.width < 360
        ? const Size(380, 286)
        : const Size(260, 220);
    state = state.copyWith(size: next);
  }

  Future<void> togglePlayPause() async {
    final controller = _pipController;
    if (controller == null) return;
    try {
      final result = await controller.evaluateJavascript(
        source: BrowserScripts.toggleMediaPlayPauseScript,
      );
      final isPlaying = result is bool ? result : !state.isPlaying;
      state = state.copyWith(isPlaying: isPlaying);
    } catch (_) {}
  }

  Future<void> reloadMedia() async {
    try {
      await _pipController?.reload();
    } catch (_) {}
  }

  /// Entra al PiP del sistema Android. La actividad completa sigue visible en
  /// una ventana 16:9; no es reproducción oculta ni un servicio de extracción.
  Future<bool> enterSystemPictureInPicture() async {
    if (!state.isActive) return false;
    try {
      return await _systemPipChannel.invokeMethod<bool>('enterSystemPip') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<_MediaTransfer?> _readMediaState(
    InAppWebViewController? controller,
  ) async {
    if (controller == null) return null;
    try {
      final raw = await controller.evaluateJavascript(
        source: BrowserScripts.readMediaStateScript,
      );
      if (raw == null) return null;
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      final position = (decoded['currentTime'] as num?)?.toDouble() ?? 0;
      final wasPlaying = decoded['wasPlaying'] == true;
      return _MediaTransfer(
        positionSeconds: position.isFinite ? position : 0,
        wasPlaying: wasPlaying,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _systemPipChannel.setMethodCallHandler(null);
    super.dispose();
  }
}

class _MediaTransfer {
  const _MediaTransfer({
    required this.positionSeconds,
    required this.wasPlaying,
  });

  final double positionSeconds;
  final bool wasPlaying;
}

final browserPipProvider =
    StateNotifierProvider<BrowserPipNotifier, BrowserPipState>((ref) {
      return BrowserPipNotifier();
    });
