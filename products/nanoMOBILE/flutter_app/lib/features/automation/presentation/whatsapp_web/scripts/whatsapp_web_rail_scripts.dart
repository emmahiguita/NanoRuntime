// whatsapp_web_rail_scripts.dart
//
// QUÉ HACE:
// Define el adaptador geométrico y las reglas CSS aisladas para la barra lateral
// vertical izquierda de navegación (navigation rail) de WhatsApp Web en modo móvil.
//
// CÓMO FUNCIONA:
// - Define la única fuente de verdad `--nano-wa-rail-width: 52px` y las clases aisladas
//   `.nano-wa-shell`, `.nano-wa-rail`, `.nano-wa-content` y `.nano-wa-content-inactive`.
// - Implementa `window.findNavigationRail()` mediante estructura, posición, dimensiones
//   y atributos semánticos de iconos sin depender únicamente de clases CSS ofuscadas.
// - Instala un único `MutationObserver` con debounce (`window.__nanoWaRailAdapter`) que
//   verifica matemáticamente `contentRect.left >= railRect.right` (`overlap: false`).
//
// POR QUÉ:
// Evita que la barra lateral izquierda comparta ancho o se superponga con los paneles
// principales (Chats, Llamadas, Estados, Comunidades, etc.), manteniendo cada archivo
// por debajo del límite de 200 líneas según Clean Architecture.

class WhatsAppWebRailScripts {
  const WhatsAppWebRailScripts._();

  /// Construye el estilo CSS aislado para el rail de navegación y el contenedor principal.
  static String buildRailStylesheet() {
    return '''
    :root { --nano-wa-rail-width: 52px; }
    html.nano-wa-web-mode, html.nano-wa-web-mode body, html.nano-wa-web-mode #app {
      width: 100vw !important; max-width: 100vw !important; min-width: 0 !important;
      height: 100% !important; margin: 0 !important; padding: 0 !important;
      overflow-x: hidden !important; transform: none !important; zoom: 1 !important;
    }
    #pane-side ~ div, div:has(> a[href*="whatsapp.com/download"]), [data-testid="download-windows-banner"] { display: none !important; }
    html.nano-wa-web-mode .nano-wa-shell {
      display: flex !important; flex-direction: row !important;
      width: 100vw !important; max-width: 100vw !important; min-width: 0 !important;
      height: 100% !important; overflow: hidden !important; position: relative !important;
      transform: none !important; zoom: 1 !important;
    }
    html.nano-wa-web-mode .nano-wa-rail {
      position: relative !important; left: 0 !important; top: 0 !important;
      width: var(--nano-wa-rail-width) !important; min-width: var(--nano-wa-rail-width) !important;
      max-width: var(--nano-wa-rail-width) !important; flex: 0 0 var(--nano-wa-rail-width) !important;
      height: 100% !important; padding-left: 6px !important; padding-right: 6px !important;
      margin: 0 !important; box-sizing: border-box !important;
      transform: none !important; zoom: 1 !important; z-index: 20 !important;
      overflow-x: visible !important; overflow-y: hidden !important;
    }
    html.nano-wa-web-mode .nano-wa-rail > div {
      width: 40px !important; min-width: 40px !important; max-width: 40px !important;
      height: 100% !important; margin: 0 auto !important; padding: 0 !important;
      box-sizing: border-box !important; transform: none !important; zoom: 1 !important;
    }
    html.nano-wa-web-mode .nano-wa-content {
      position: relative !important; left: 0 !important; margin-left: 0 !important;
      inset-inline-start: 0 !important; flex: 1 1 auto !important;
      width: calc(100vw - var(--nano-wa-rail-width)) !important;
      max-width: calc(100vw - var(--nano-wa-rail-width)) !important;
      min-width: 0 !important; height: 100% !important;
      overflow-x: hidden !important; box-sizing: border-box !important;
      transform: none !important; zoom: 1 !important;
    }
    html.nano-wa-web-mode .nano-wa-content-inactive { display: none !important; }
    html.nano-wa-web-mode .nano-wa-content > div:first-child {
      margin-left: 0 !important; inset-inline-start: 0 !important; left: 0 !important;
      width: 100% !important; max-width: 100% !important; min-width: 0 !important; flex: 1 1 100% !important;
    }
    html.nano-wa-web-mode .nano-wa-drawer-host > div:nth-child(2) { display: none !important; }
    html.nano-wa-web-mode #side, html.nano-wa-web-mode #main { width: 100% !important; max-width: 100% !important; min-width: 0 !important; }
    html.nano-wa-web-mode #main > header { padding-left: 8px !important; padding-right: 6px !important; box-sizing: border-box !important; }
    html.nano-wa-web-mode #main div[role="row"] { padding-left: 2px !important; padding-right: 2px !important; box-sizing: border-box !important; }
    html.nano-wa-web-mode #main .focusable-list-item { padding-left: 10px !important; padding-right: 10px !important; box-sizing: border-box !important; }
    html.nano-wa-web-mode #main .focusable-list-item > div { max-width: calc(100vw - var(--nano-wa-rail-width) - 24px) !important; box-sizing: border-box !important; }
    html.nano-wa-web-mode #main .focusable-list-item div.x121pien {
      width: 264px !important; max-width: calc(100vw - var(--nano-wa-rail-width) - 36px) !important; box-sizing: border-box !important;
    }
    html.nano-wa-web-mode #main .focusable-list-item div.x121pien > div,
    html.nano-wa-web-mode #main .focusable-list-item div.x15zctf7,
    html.nano-wa-web-mode #main .focusable-list-item div.x2fvf9 {
      width: 100% !important; max-width: 100% !important; min-width: 0 !important; box-sizing: border-box !important;
    }
    html.nano-wa-web-mode #nano-wa-header-back-btn {
      width: 36px !important; height: 36px !important; border: none !important; background: transparent !important;
      display: inline-flex !important; align-items: center !important; justify-content: center !important; color: inherit !important;
    }
    html.nano-wa-web-mode #pane-side { -webkit-overflow-scrolling: touch !important; overflow-y: auto !important; touch-action: pan-y !important; }
    ''';
  }

  /// Construye el script detector y adaptador reactivo del rail izquierdo (`window.__nanoWaRailAdapter`).
  static String buildRailAdapterScript() {
    final css = buildRailStylesheet().replaceAll('\n', ' ').replaceAll("'", r"\'");
    return '''
    var railStyle = document.getElementById('nano-wa-web-mode-banner-fix');
    if (!railStyle) {
      railStyle = document.createElement('style');
      railStyle.id = 'nano-wa-web-mode-banner-fix';
      document.head.appendChild(railStyle);
    }
    railStyle.textContent = '$css';

    window.findNavigationRail = function() {
      var shell = document.querySelector('.two') || document.getElementById('app');
      if (!shell) return null;
      var candidates = Array.from(shell.children);
      for (var i = 0; i < candidates.length; i++) {
        var el = candidates[i];
        if (!el || el.id === 'wds-toast-container' || el.querySelector('#side') || el.querySelector('#main')) continue;
        var btns = el.querySelectorAll('button, [role="button"]');
        var hasNavIcons = !!(
          el.querySelector('[data-icon*="chat"], [data-icon*="call"], [data-icon*="status"], [data-icon*="community"], [data-icon*="newsletter"]') ||
          el.tagName === 'HEADER'
        );
        var rect = el.getBoundingClientRect();
        if (btns.length >= 4 && hasNavIcons && rect.left <= 4 && rect.height > 200 && rect.width <= 96) return el;
      }
      return document.querySelector('.two > header');
    };

    function applyRailGeometry() {
      if (!document.documentElement.classList.contains('nano-wa-web-mode')) return null;
      var rail = window.findNavigationRail();
      if (!rail || !rail.parentElement) return null;
      var shell = rail.parentElement;
      shell.classList.add('nano-wa-shell');
      rail.classList.add('nano-wa-rail');
      rail.classList.remove('nano-wa-content', 'nano-wa-content-inactive');

      var siblings = Array.from(shell.children).filter(function(el) {
        return el !== rail && el.id !== 'wds-toast-container' && el.tagName !== 'STYLE' && el.tagName !== 'SCRIPT';
      });
      var drawerHost = null, chatListHost = null, chatMainHost = null;
      siblings.forEach(function(el) {
        el.classList.remove('nano-wa-content', 'nano-wa-content-inactive', 'nano-wa-drawer-host');
        var hasDrawerContent = !!(el.classList.contains('x1o0tod') && el.querySelector(':scope > div:first-child > div > span > div'));
        if (hasDrawerContent) drawerHost = el;
        else if (el.querySelector('#side') && !el.classList.contains('x10l6tqk')) chatListHost = el;
        else if (el.querySelector('#main') && !el.classList.contains('x10l6tqk')) chatMainHost = el;
      });

      var isWebChat = document.body.classList.contains('nano-web-chat') && !!chatMainHost;
      var activeContent = drawerHost || (isWebChat ? chatMainHost : chatListHost);
      if (drawerHost) drawerHost.classList.add('nano-wa-drawer-host');

      siblings.forEach(function(el) {
        el.classList.toggle('nano-wa-content', el === activeContent);
        el.classList.toggle('nano-wa-content-inactive', el !== activeContent);
      });

      var railRect = rail.getBoundingClientRect();
      var contentRect = activeContent ? activeContent.getBoundingClientRect() : { left: 0, right: 0, width: 0, height: 0 };
      var overlap = activeContent ? (contentRect.left < railRect.right - 1.5) : false;
      console.log('[NanoWA] rail detected');
      console.log('[NanoWA] rail width: ' + Math.round(railRect.width));
      console.log('[NanoWA] rail right: ' + Math.round(railRect.right));
      console.log('[NanoWA] content left: ' + Math.round(contentRect.left));
      console.log('[NanoWA] overlap: ' + overlap);
      return {
        railWidth: Math.round(railRect.width), railX: Math.round(railRect.left), railRight: Math.round(railRect.right),
        contentLeft: Math.round(contentRect.left), contentWidth: Math.round(contentRect.width), overlap: overlap,
        horizontalOverflow: Math.max(0, document.documentElement.scrollWidth - window.innerWidth),
        railVisible: railRect.width > 0 && railRect.height > 0
      };
    }

    if (window.__nanoWaRailAdapter?.disconnect) window.__nanoWaRailAdapter.disconnect();
    var railTimer = null;
    var railObs = new MutationObserver(function() {
      if (railTimer) clearTimeout(railTimer);
      railTimer = setTimeout(applyRailGeometry, 50);
    });
    var railRoot = document.getElementById('app') || document.body;
    if (railRoot) railObs.observe(railRoot, { childList: true, subtree: true });
    window.__nanoWaRailAdapter = {
      observer: railObs, apply: applyRailGeometry,
      disconnect: function() { if (railTimer) clearTimeout(railTimer); railObs.disconnect(); }
    };
    applyRailGeometry();
    ''';
  }

  /// Desconecta el observador de la barra lateral cuando se suspende la vista.
  static String buildSuspendRailAdapterScript() {
    return '''
    if (window.__nanoWaRailAdapter?.disconnect) window.__nanoWaRailAdapter.disconnect();
    window.__nanoWaRailAdapter = null;
    ''';
  }
}
