// QUÉ: Soporte de zoom táctil nativo y compatibilidad con viewport responsivo.
// CÓMO: Permite que Android WebView maneje el pellizco multitáctil por hardware sin interrupciones.
// POR QUÉ: Evita distorsiones en elementos fijos (position: fixed) y pérdida de imagen en el renderizado.

import 'browser_zoom_scripts.dart';

class BrowserPinchZoomEngine {
  const BrowserPinchZoomEngine._();

  static const pinchZoomScript = """
  ${BrowserZoomScripts.installZoomScript}
  (function() {
    if (window.__nanoPinchEngineInstalled) return;
    window.__nanoPinchEngineInstalled = true;
    
    // Asegurar que el viewport permita escalado de usuario
    try {
      let vp = document.querySelector('meta[name="viewport"]');
      if (vp) {
        let c = vp.getAttribute('content') || '';
        if (c.includes('user-scalable=no') || c.includes('maximum-scale=1')) {
          vp.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes');
        }
      }
    } catch (_) {}
    
    window.addEventListener('resize', function() {
      if (window.flutter_inappwebview?.callHandler && window.__nanoZoomLevel) {
        window.flutter_inappwebview.callHandler('nanoZoomUpdate', window.__nanoZoomLevel);
      }
    }, { passive: true });
  })();
  """;
}
