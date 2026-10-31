// QUÉ: Scripts de inyección de zoom CSS y viewport adapters para Nano Browser.
// CÓMO: Permite zoom libre desde 5% (0.05) hasta 500% (5.0) en raíz html sin distorsionar el sitio.
// POR QUÉ: Otorga escalado continuo libre sin límites artificiales (< 100 líneas).
class BrowserZoomScripts {
  const BrowserZoomScripts._();

  static const installZoomScript = """
  (function() {
    if (window.__nanoApplyZoom) return;
    const root = document.documentElement;
    const originalZoom = root.style.getPropertyValue('zoom');
    const originalPriority = root.style.getPropertyPriority('zoom');
    const baseZoom = parseFloat(getComputedStyle(root).zoom) || 1;
    window.__nanoZoomLevel = 1;
    window.__nanoApplyZoom = function(value) {
      const scale = Math.max(0.05, Math.min(5.0, Number(value) || 1));
      if (scale === 1) {
        if (originalZoom) root.style.setProperty('zoom', originalZoom, originalPriority);
        else root.style.removeProperty('zoom');
      } else {
        root.style.setProperty('zoom', String(baseZoom * scale), 'important');
      }
      window.__nanoZoomLevel = scale;
      return scale;
    };
  })();
  """;

  /// Actualiza la misma escala que consulta el siguiente gesto de pellizco.
  static String setZoomLevelScript(double scale) {
    final safeScale = scale.isFinite ? scale.clamp(0.05, 5.0) : 1.0;
    return '$installZoomScript window.__nanoApplyZoom($safeScale);';
  }

  /// Mide a escala natural, para no acumular reducciones en cada pulsación.
  static const fitToScreenOverviewScript = """
  $installZoomScript
  (function() {
    const previous = window.__nanoZoomLevel || 1;
    window.__nanoApplyZoom(1);
    const root = document.documentElement;
    const width = Math.max(root.scrollWidth, document.body?.scrollWidth || 0);
    const viewport = root.clientWidth || window.innerWidth;
    const ratio = width > 0 ? Math.min(viewport / width, 1) : 1;
    window.__nanoApplyZoom(previous);
    return Math.max(0.05, ratio);
  })();
  """;

  /// El modo móvil restaura el viewport permitiendo reducción libre desde 5%.
  static const mobileViewportAdapterScript = """
  (function() {
    const content = 'width=device-width, initial-scale=1, minimum-scale=0.05, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover';
    const applyViewport = function() {
      const head = document.head;
      if (!head) return false;
      const viewports = document.querySelectorAll('meta[name="viewport"]');
      let vp = viewports.length ? viewports[0] : null;
      if (!vp) {
        vp = document.createElement('meta');
        vp.name = 'viewport';
        head.prepend(vp);
      }
      vp.setAttribute('content', content);
      for (let i = 1; i < viewports.length; i++) viewports[i].remove();
      return true;
    };
    applyViewport();
    document.addEventListener('DOMContentLoaded', applyViewport, { once: true });
    window.addEventListener('pageshow', applyViewport, { once: true });
  })();
  """;

  static const adaptiveDesktopViewportAdapterScript =
      mobileViewportAdapterScript;

  /// El motor nativo calcula el overview de escritorio con reducción libre permitida.
  static const desktopViewportAdapterScript = """
  (function() {
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.name = 'viewport';
      (document.head || document.documentElement).appendChild(vp);
    }
    vp.content = 'width=1280, minimum-scale=0.05, maximum-scale=5.0, user-scalable=yes';
  })();
  """;
}
