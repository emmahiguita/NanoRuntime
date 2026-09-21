/// Scripts JavaScript acotados para adaptar páginas y controlar el elemento
/// multimedia visible. No falsean la Page Visibility API ni fuerzan audio con
/// la aplicación oculta: la continuidad externa se resuelve con PiP nativo.
class BrowserScripts {
  /// Lee el medio HTML activo antes de transferirlo a la superficie PiP.
  /// Devuelve un JSON String para mantener estable el codec del MethodChannel.
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

  /// Detiene la fuente cuando el usuario mueve la reproducción al PiP. Así
  /// nunca quedan dos reproductores sonando a la vez.
  static const String pauseMediaScript = """
  (function() {
    try {
      const media = Array.from(document.querySelectorAll('video, audio'));
      media.forEach(function(item) { if (!item.paused) item.pause(); });
      return media.length > 0;
    } catch(e) { return false; }
  })();
  """;

  /// Restaura tiempo y estado en el reproductor PiP visible. La búsqueda tiene
  /// un límite breve porque algunos sitios montan su elemento de video tarde.
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

  /// Script inyectado para adaptar páginas al viewport de móviles y corregir errores de subpíxel
  static const String mobileViewportAdapterScript = """
  (function() {
    function applyViewport() {
      try {
        const metas = document.querySelectorAll('meta[name="viewport"]');
        metas.forEach(function(m) { m.remove(); });

        let meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, minimum-scale=0.01, maximum-scale=5.0, user-scalable=yes';
        (document.head || document.documentElement).appendChild(meta);

        if (!document.getElementById('__nano_pixel_fix')) {
          const style = document.createElement('style');
          style.id = '__nano_pixel_fix';
          style.innerHTML = `
            html, body {
              overflow-x: hidden !important;
              max-width: 100% !important;
              width: 100% !important;
              box-sizing: border-box !important;
              -webkit-text-size-adjust: 100% !important;
            }
            * {
              box-sizing: border-box !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        }
      } catch(e) {}
    }

    applyViewport();
    if (document.readyState !== 'complete') {
      window.addEventListener('DOMContentLoaded', applyViewport);
      window.addEventListener('load', applyViewport);
    }
  })();
  """;

  /// Motor de gesto táctil de 2 dedos (Pinch to Zoom / Reducir sin límites)
  /// Permite reducir la página de forma idéntica al botón "Reducir" mediante pellizco.
  static const String pinchZoomEngineScript = """
  (function() {
    if (window.__nanoPinchInstalled) return;
    window.__nanoPinchInstalled = true;

    let initialDist = 0;
    let baseZoom = 1.0;
    let currentZoom = 1.0;

    function getDistance(t1, t2) {
      const dx = t1.clientX - t2.clientX;
      const dy = t1.clientY - t2.clientY;
      return Math.sqrt(dx * dx + dy * dy);
    }

    window.addEventListener('touchstart', function(e) {
      if (e.touches.length === 2) {
        initialDist = getDistance(e.touches[0], e.touches[1]);
        const styleZoom = parseFloat(document.body.style.zoom || '1.0');
        baseZoom = Number.isFinite(styleZoom) && styleZoom > 0 ? styleZoom : 1.0;
      }
    }, { passive: true });

    window.addEventListener('touchmove', function(e) {
      if (e.touches.length === 2 && initialDist > 15) {
        const dist = getDistance(e.touches[0], e.touches[1]);
        const ratio = dist / initialDist;
        currentZoom = Math.min(Math.max(baseZoom * ratio, 0.15), 4.5);

        document.body.style.zoom = currentZoom;
        if (getComputedStyle(document.body).zoom === undefined) {
          document.body.style.transform = 'scale(' + currentZoom + ')';
          document.body.style.transformOrigin = 'top left';
          document.body.style.width = (100 / currentZoom) + '%';
        }

        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('nanoZoomUpdate', currentZoom);
        }
        if (e.cancelable) {
          e.preventDefault();
        }
      }
    }, { passive: false });

    window.addEventListener('touchend', function(e) {
      if (e.touches.length < 2) {
        initialDist = 0;
      }
    }, { passive: true });
  })();
  """;

  /// Script inyectado en modo escritorio profesional para forzar layout ancho de 1280px y overview
  static const String desktopViewportAdapterScript = """
  (function() {
    function applyDesktop() {
      try {
        const metas = document.querySelectorAll('meta[name="viewport"]');
        metas.forEach(function(m) { m.remove(); });

        let meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=1280, initial-scale=0.32, minimum-scale=0.01, maximum-scale=5.0, user-scalable=yes';
        (document.head || document.documentElement).appendChild(meta);

        if (document.documentElement) {
          document.documentElement.style.minWidth = '1280px';
          document.documentElement.style.touchAction = 'pan-x pan-y pinch-zoom';
        }
        if (document.body) {
          document.body.style.minWidth = '1280px';
          document.body.style.touchAction = 'pan-x pan-y pinch-zoom';
        }
      } catch(e) {}
    }

    applyDesktop();
    if (document.readyState !== 'complete') {
      window.addEventListener('DOMContentLoaded', applyDesktop);
      window.addEventListener('load', applyDesktop);
    }
  })();
  """;

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

  /// Ajustar zoom CSS programático (soporta tanto zoom in como reducción de tamaño zoom out)
  static String setZoomLevelScript(double scale) {
    return """
    (function() {
      try {
        document.body.style.zoom = '$scale';
        if (getComputedStyle(document.body).zoom === undefined) {
          document.body.style.transform = 'scale($scale)';
          document.body.style.transformOrigin = 'top left';
          document.body.style.width = (100 / $scale) + '%';
        }
      } catch(e) {}
    })();
    """;
  }

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

  /// Script inyectado para detectar inicios de sesión e interceptar formularios de autenticación
  static const String credentialManagerScript = """
  (function() {
    if (window.__nanoCredentialManagerInstalled) return;
    window.__nanoCredentialManagerInstalled = true;

    function extractAndSendCredentials(form) {
      try {
        let root = form || document;
        let passInput = root.querySelector('input[type="password"]');
        if (!passInput || !passInput.value) return;

        let password = passInput.value;
        let userInput = null;

        // Buscar campo de usuario previo al password en el mismo formulario o contenedor
        let inputs = Array.from(root.querySelectorAll('input:not([type="hidden"]):not([type="password"]):not([type="submit"]):not([type="button"])'));
        for (let inp of inputs) {
          let type = (inp.type || '').toLowerCase();
          let name = (inp.name || '').toLowerCase();
          let id = (inp.id || '').toLowerCase();
          let auto = (inp.autocomplete || '').toLowerCase();
          if (type === 'email' || auto.includes('username') || auto.includes('email') ||
              name.includes('user') || name.includes('email') || name.includes('login') ||
              id.includes('user') || id.includes('email') || id.includes('login')) {
            if (inp.value && inp.value.trim().length > 0) {
              userInput = inp;
              break;
            }
          }
        }

        if (!userInput && inputs.length > 0) {
          // Tomar el último input visible antes del campo de contraseña
          for (let i = inputs.length - 1; i >= 0; i--) {
            if (inputs[i].value && inputs[i].value.trim().length > 0) {
              userInput = inputs[i];
              break;
            }
          }
        }

        let username = userInput ? userInput.value.trim() : '';
        if (password.length > 0 && window.flutter_inappwebview) {
          let host = window.location.hostname || '';
          window.flutter_inappwebview.callHandler('nanoSaveCredential', host, username, password);
        }
      } catch(e) {}
    }

    // Escuchar envíos nativos de formulario
    document.addEventListener('submit', function(e) {
      extractAndSendCredentials(e.target);
    }, true);

    // Escuchar clicks en botones de envío o login
    document.addEventListener('click', function(e) {
      let btn = e.target.closest('button, input[type="submit"], [role="button"]');
      if (btn) {
        let text = (btn.innerText || btn.value || '').toLowerCase();
        if (text.includes('log in') || text.includes('iniciar') || text.includes('sign in') ||
            text.includes('acceder') || text.includes('entrar') || text.includes('submit')) {
          let form = btn.closest('form');
          extractAndSendCredentials(form);
        }
      }
    }, true);

    // Función de autocompletado segura expuesta en window
    window.__nanoAutofill = function(user, pass) {
      try {
        let passInput = document.querySelector('input[type="password"]');
        if (!passInput) return false;

        let root = passInput.closest('form') || document;
        let inputs = Array.from(root.querySelectorAll('input:not([type="hidden"]):not([type="password"]):not([type="submit"]):not([type="button"])'));
        let userInput = null;

        for (let inp of inputs) {
          let type = (inp.type || '').toLowerCase();
          let name = (inp.name || '').toLowerCase();
          let id = (inp.id || '').toLowerCase();
          let auto = (inp.autocomplete || '').toLowerCase();
          if (type === 'email' || auto.includes('username') || auto.includes('email') ||
              name.includes('user') || name.includes('email') || name.includes('login') ||
              id.includes('user') || id.includes('email') || id.includes('login')) {
            userInput = inp;
            break;
          }
        }
        if (!userInput && inputs.length > 0) {
          userInput = inputs[inputs.length - 1];
        }

        if (userInput && user) {
          userInput.value = user;
          userInput.dispatchEvent(new Event('input', { bubbles: true }));
          userInput.dispatchEvent(new Event('change', { bubbles: true }));
        }

        if (passInput && pass) {
          passInput.value = pass;
          passInput.dispatchEvent(new Event('input', { bubbles: true }));
          passInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
        return true;
      } catch(e) { return false; }
    };
  })();
  """;

  /// Genera la llamada Javascript para autocompletar credenciales específicas
  static String buildAutofillScript(String username, String password) {
    final u = username.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final p = password.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    return "if (window.__nanoAutofill) { window.__nanoAutofill('$u', '$p'); }";
  }
}

