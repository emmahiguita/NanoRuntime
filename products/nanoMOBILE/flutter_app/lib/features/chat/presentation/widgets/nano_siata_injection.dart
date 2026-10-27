import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Inyección segura y no destructiva de CSS / JS para el geoportal SIATA.
/// Garantiza que el mapa y los datos reales se muestren al 100% de ancho y alto,
/// cerrando modales promocionales de forma natural y forzando el renderizado de capas.
class NanoSiataInjection {
  static const String cleanScript = '''
  (function() {
    // 1. Cerrar diálogos/modales promocionales con su botón de cierre natural
    const closeButtons = document.querySelectorAll(
      'button[aria-label="Close"], button[aria-label="Cerrar"], .btn-close, .modal-header .close, .close-modal, .banner-close'
    );
    closeButtons.forEach(b => {
      try { b.click(); } catch(e) {}
    });

    // 2. Estilos no destructivos para expandir el mapa al ancho completo
    const styleId = 'nano-siata-safe-css';
    let style = document.getElementById(styleId);
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      style.innerHTML = `
        /* Eliminar banners promocionales no esenciales */
        .banner-promo, .promo-banner, div[class*="banner-promo"], div[class*="promo-banner"] {
          display: none !important;
        }

        /* Ocultar control de zoom de leaflet duplicado para usar los de cristal iOS */
        .leaflet-control-zoom {
          display: none !important;
        }

        /* Ocupar el 100% de la ventana sin márgenes */
        html, body {
          width: 100% !important;
          height: 100% !important;
          margin: 0 !important;
          padding: 0 !important;
          overflow: hidden !important;
        }

        #map, .leaflet-container {
          width: 100% !important;
          height: 100% !important;
          min-width: 100% !important;
          min-height: 100% !important;
          touch-action: auto !important;
        }
      `;
      document.head.appendChild(style);
    }

    // 3. Forzar redibujado y ajuste de tamaño del mapa en Leaflet / OpenLayers
    if (window.map) {
      try {
        if (window.map.invalidateSize) {
          window.map.invalidateSize({ pan: false });
        }
        if (window.map.touchZoom) window.map.touchZoom.enable();
        if (window.map.doubleClickZoom) window.map.doubleClickZoom.enable();
        if (window.map.scrollWheelZoom) window.map.scrollWheelZoom.enable();
        if (window.map.dragging) window.map.dragging.enable();
      } catch(e) {}
    }
  })();
  ''';

  static void inject(InAppWebViewController? controller) {
    controller?.evaluateJavascript(source: cleanScript);
  }
}
