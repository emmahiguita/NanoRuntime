/// Zoom CSS compartido por slider, ajuste y pellizco.
/// Se escala solo la raíz: escalar también body multiplicaba la reducción.
/// No modifica estilos del sitio ni el viewport salvo adaptación explícita.
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
      const scale = Math.max(0.1, Math.min(3, Number(value) || 1));
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
    final safeScale = scale.isFinite ? scale.clamp(0.1, 3.0) : 1.0;
    return '$installZoomScript window.__nanoApplyZoom($safeScale);';
  }

  /// Mide a escala natural, para no acumular reducciones en cada pulsación.
  static const fitToScreenOverviewScript =
      """
  $installZoomScript
  (function() {
    const previous = window.__nanoZoomLevel || 1;
    window.__nanoApplyZoom(1);
    const root = document.documentElement;
    const width = Math.max(root.scrollWidth, document.body?.scrollWidth || 0);
    const viewport = root.clientWidth || window.innerWidth;
    const ratio = width > 0 ? Math.min(viewport / width, 1) : 1;
    window.__nanoApplyZoom(previous);
    return Math.max(0.1, ratio);
  })();
  """;

  /// El modo móvil restaura el viewport; no fuerza anchos en html ni body.
  static const mobileViewportAdapterScript = """
  (function() {
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.name = 'viewport';
      (document.head || document.documentElement).appendChild(vp);
    }
    vp.content = 'width=device-width, initial-scale=1, user-scalable=yes';
  })();
  """;

  /// El motor nativo calcula el overview de escritorio según el ancho real.
  static const desktopViewportAdapterScript = """
  (function() {
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.name = 'viewport';
      (document.head || document.documentElement).appendChild(vp);
    }
    vp.content = 'width=1280, user-scalable=yes';
  })();
  """;
}
