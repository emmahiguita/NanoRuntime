import 'browser_zoom_scripts.dart';

/// Un solo motor de escala para los gestos y controles Flutter.
/// Agrupa movimientos por frame y publica una sola actualización al terminar.
class BrowserPinchZoomEngine {
  const BrowserPinchZoomEngine._();

  static const pinchZoomScript =
      """
  ${BrowserZoomScripts.installZoomScript}
  (function() {
    if (window.__nanoPinchEngineInstalled) return;
    window.__nanoPinchEngineInstalled = true;
    let startDist = 0, baseZoom = 1, target = 1;
    let isPinching = false, rafId = null;
    function distance(touches) {
      return Math.hypot(touches[0].clientX - touches[1].clientX,
        touches[0].clientY - touches[1].clientY);
    }
    function render() {
      rafId = null;
      window.__nanoApplyZoom(target);
    }
    window.addEventListener('touchstart', function(e) {
      if (e.touches.length !== 2) return;
      startDist = distance(e.touches);
      baseZoom = target = window.__nanoZoomLevel || 1;
      isPinching = startDist > 0;
      // Evitar que el WebView aplique además un segundo zoom nativo.
      if (isPinching && e.cancelable) e.preventDefault();
    }, { passive: false });
    window.addEventListener('touchmove', function(e) {
      if (!isPinching || e.touches.length !== 2) return;
      if (e.cancelable) e.preventDefault();
      target = Math.max(0.1, Math.min(3, baseZoom * distance(e.touches) / startDist));
      if (rafId === null) rafId = requestAnimationFrame(render);
    }, { passive: false });
    function endPinch(e) {
      if (!isPinching || e.touches.length >= 2) return;
      isPinching = false;
      // Aplicar el último frame antes de notificar; no dejar callbacks pendientes.
      if (rafId !== null) cancelAnimationFrame(rafId);
      render();
      if (window.flutter_inappwebview?.callHandler) {
        window.flutter_inappwebview.callHandler('nanoZoomUpdate', window.__nanoZoomLevel);
      }
    }
    window.addEventListener('touchend', endPinch, { passive: true });
    window.addEventListener('touchcancel', endPinch, { passive: true });
    window.addEventListener('pagehide', function() {
      if (rafId !== null) cancelAnimationFrame(rafId);
      rafId = null;
      isPinching = false;
    });
  })();
  """;
}
