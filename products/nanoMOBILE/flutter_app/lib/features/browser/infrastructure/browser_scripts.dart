import 'browser_zoom_scripts.dart';
import 'browser_auth_scripts.dart';
import 'browser_pinch_zoom_engine.dart';

export 'browser_zoom_scripts.dart';
export 'browser_auth_scripts.dart';
export 'browser_pinch_zoom_engine.dart';

/// QUÉ HACE:
/// Fachada central de scripts JavaScript inyectados en InAppWebView (Media, Dark Mode, PiP).
/// 
/// CÓMO FUNCIONA:
/// Delega scripts de zoom a BrowserZoomScripts y scripts de auth a BrowserAuthScripts,
/// manteniendo compatibilidad con todo el código existente.
/// 
/// POR QUÉ:
/// Aplica el principio de Responsabilidad Única (SOLID) y arquitectura limpia,
/// garantizando que ningún archivo supere las 150 líneas de código.
class BrowserScripts {
  /// Lee el medio HTML activo antes de transferirlo a la superficie PiP.
  static const String readMediaStateScript = """
  (function() {
    try {
      const media = Array.from(document.querySelectorAll('video, audio'));
      const active = media.find(function(item) {
        return !item.paused && !item.ended;
      }) || media[0];
      if (!active) return null;
      return JSON.stringify({
        currentTime: Number.isFinite(active.currentTime) ? active.currentTime : 0,
        duration: Number.isFinite(active.duration) ? active.duration : 0,
        wasPlaying: !active.paused && !active.ended
      });
    } catch(e) { return null; }
  })();
  """;

  /// Detiene la fuente cuando el usuario mueve la reproducción al PiP.
  static const String pauseMediaScript = """
  (function() {
    try {
      const media = Array.from(document.querySelectorAll('video, audio'));
      media.forEach(function(item) { if (!item.paused) item.pause(); });
      return media.length > 0;
    } catch(e) { return false; }
  })();
  """;

  /// Restaura tiempo y estado en el reproductor PiP visible.
  static String restoreVisibleMediaScript({
    required double positionSeconds,
    required bool shouldPlay,
  }) {
    final position = positionSeconds.isFinite
        ? positionSeconds.clamp(0, 86400).toStringAsFixed(3)
        : '0';
    return """
    (function() {
      let attempts = 0;
      const timer = setInterval(function() {
        attempts += 1;
        const media = document.querySelector('video, audio');
        if (!media) {
          if (attempts >= 20) clearInterval(timer);
          return;
        }
        clearInterval(timer);
        try {
          const target = $position;
          if (target > 0 && Number.isFinite(media.duration)) {
            media.currentTime = Math.min(target, Math.max(0, media.duration - 0.25));
          }
          if (${shouldPlay ? 'true' : 'false'}) {
            media.play().catch(function(){});
          } else {
            media.pause();
          }
        } catch(e) {}
      }, 250);
      return true;
    })();
    """;
  }

  /// Alternar reproducción / pausa de cualquier video o audio activo en la página
  static const String toggleMediaPlayPauseScript = """
  (function() {
    const videos = Array.from(document.querySelectorAll('video, audio'));
    let foundPlaying = false;
    for (let v of videos) {
      if (!v.paused && !v.ended && v.readyState > 2) {
        v.pause();
        foundPlaying = true;
      }
    }
    if (!foundPlaying && videos.length > 0) {
      videos[0].play().catch(function(){});
      return true;
    }
    return !foundPlaying;
  })();
  """;

  /// Script para forzar modo oscuro de alto contraste e invertir colores suavemente
  static const String toggleDarkModeWebScript = """
  (function() {
    let darkStyle = document.getElementById('__nano_dark_style');
    if (darkStyle) {
      darkStyle.remove();
      return false;
    } else {
      darkStyle = document.createElement('style');
      darkStyle.id = '__nano_dark_style';
      darkStyle.innerHTML = `
        html { filter: invert(90%) hue-rotate(180deg) !important; background: #121212 !important; }
        img, video, iframe, canvas, svg { filter: invert(100%) hue-rotate(180deg) !important; }
      `;
      document.head.appendChild(darkStyle);
      return true;
    }
  })();
  """;

  /// User Agent de escritorio profesional (Chrome 130 Windows 64-bit)
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  // --- Delegaciones de Zoom y Viewport ---
  static const String pinchZoomEngineScript = BrowserPinchZoomEngine.pinchZoomScript;
  static String setZoomLevelScript(double scale) => BrowserZoomScripts.setZoomLevelScript(scale);
  static const String fitToScreenOverviewScript = BrowserZoomScripts.fitToScreenOverviewScript;
  static const String mobileViewportAdapterScript = BrowserZoomScripts.mobileViewportAdapterScript;
  static const String desktopViewportAdapterScript = BrowserZoomScripts.desktopViewportAdapterScript;

  // --- Delegaciones de Autenticación y Credenciales ---
  static const String credentialManagerScript = BrowserAuthScripts.credentialManagerScript;
  static String buildAutofillScript(String username, String password) =>
      BrowserAuthScripts.buildAutofillScript(username, password);
}
