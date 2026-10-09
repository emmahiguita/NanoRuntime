import 'dart:async';
import 'dart:ui' show Offset, Size;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/main.dart' show audioHandler;

import '../domain/browser_pip_model.dart';
import '../infrastructure/browser_scripts.dart';
import 'browser_media_transfer_reader.dart';
import 'browser_system_pip_bridge.dart';

/// Coordina una transferencia explícita entre el WebView de la pestaña y el
/// reproductor PiP visible. La fuente se pausa antes de montar el destino para
/// impedir audio duplicado y nunca se falsea la visibilidad de la página.
class BrowserPipNotifier extends StateNotifier<BrowserPipState> {
  BrowserPipNotifier() : super(const BrowserPipState()) {
    _systemPip = BrowserSystemPipBridge(
      onModeChanged: (active) => state = state.copyWith(isSystemPip: active),
      onUserLeaveHint: () {
        if (state.isActive && !state.isSystemPip) {
          unawaited(enterSystemPictureInPicture());
        }
      },
    );
  }

  late final BrowserSystemPipBridge _systemPip;
  InAppWebViewController? _sourceController;
  InAppWebViewController? _pipController;

  /// Registra la pestaña fuente actualmente visible.
  void attachController(InAppWebViewController? controller) =>
      _sourceController = controller;

  /// La ventana PiP usa la misma sesión Android que las pestañas normales.
  void attachPipController(InAppWebViewController? controller) {
    _pipController = controller;
    if (controller != null) {
      audioHandler.attachSource('browser-pip', controller);
    }
  }

  /// Mueve la reproducción al PiP. Devuelve true cuando se encontró un medio HTML.
  Future<bool> activatePip({
    required String tabId,
    required String url,
    required String title,
    InAppWebViewController? controller,
  }) async {
    _sourceController = controller ?? _sourceController;
    final media = await BrowserMediaTransferReader.read(_sourceController);
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

  /// Se invoca cuando el WebView PiP terminó de cargar.
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
    audioHandler.detachSource('browser-pip');
    state = state.copyWith(
      isActive: false,
      isPlaying: false,
      isSystemPip: false,
      isMaximized: false,
      transferPending: false,
    );
  }

  // Alterna entre modo compacto y expandido del PiP (era bug: siempre forzaba false)
  void toggleCompact() => state = state.copyWith(isCompact: !state.isCompact);

  void toggleMaximized() =>
      state = state.copyWith(isMaximized: !state.isMaximized);

  void updatePosition(Offset newPosition, Size screenSize) {
    final x = newPosition.dx.clamp(
      8.0,
      (screenSize.width - state.size.width - 8).clamp(8.0, double.infinity),
    );
    final y = newPosition.dy.clamp(
      40.0,
      (screenSize.height - state.size.height - 40).clamp(40.0, double.infinity),
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
    return _systemPip.enter();
  }

  @override
  void dispose() {
    audioHandler.detachSource('browser-pip');
    _systemPip.dispose();
    super.dispose();
  }
}

final browserPipProvider =
    StateNotifierProvider<BrowserPipNotifier, BrowserPipState>((ref) {
      return BrowserPipNotifier();
    });
