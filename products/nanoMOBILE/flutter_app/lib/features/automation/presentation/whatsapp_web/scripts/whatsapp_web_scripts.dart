// whatsapp_web_scripts.dart
//
// QUÉ HACE:
// Fachada para la inyección de scripts JS en WhatsApp Web InAppWebView.
// Adapta la interfaz responsive móvil y sincroniza el estado de navegación de chats.
//
// CÓMO FUNCIONA:
// - buildResponsiveScript: Configura el viewport dinámico móvil y aplica estilos CSS.
// - buildObserverScript: Observa mutaciones en el DOM para detectar si el usuario está en
//   la lista de contactos o dentro de una conversación (incluyendo grabación de voz y medios).
// - Detecta `#main` mediante su header/footer para mantener el chat visible durante notas de voz.
//
// POR QUÉ:
// Respeta SOLID (SRP, Facade), mantiene los scripts desacoplados y < 200 líneas.

import 'whatsapp_web_navigation_scripts.dart';
import 'whatsapp_web_touch_scripts.dart';

export 'whatsapp_web_navigation_scripts.dart';
export 'whatsapp_web_touch_scripts.dart';

class WhatsAppWebScripts {
  const WhatsAppWebScripts._();

  /// Script de inicialización responsive: viewport móvil escalable y utilidades DOM.
  static String buildResponsiveScript({
    required String encodedCss,
    required String variant,
  }) {
    return '''
    (function() {
      var vp = document.querySelector('meta[name="viewport"]');
      var existed = !!vp;
      if (!vp) { vp = document.createElement('meta'); vp.name = 'viewport'; document.head.appendChild(vp); }
      if (vp.dataset.nanoCaptured !== 'true') {
        vp.dataset.nanoCaptured = 'true';
        vp.dataset.nanoExisted = existed ? 'true' : 'false';
        vp.dataset.nanoContent = vp.getAttribute('content') || '';
      }
      var content = '$variant' === 'mobile'
          ? 'width=device-width, initial-scale=0.85, minimum-scale=0.5, maximum-scale=5, user-scalable=yes, viewport-fit=cover, interactive-widget=resizes-content'
          : 'width=device-width, initial-scale=1, minimum-scale=0.75, maximum-scale=5, user-scalable=yes, viewport-fit=cover, interactive-widget=resizes-content';
      if (vp.dataset.nanoVariant !== '$variant') {
        vp.setAttribute('content', content);
        vp.dataset.nanoVariant = '$variant';
      }

      var style = document.getElementById('nano-wa-responsive-style');
      if (!style) { style = document.createElement('style'); style.id = 'nano-wa-responsive-style'; document.head.appendChild(style); }
      style.textContent = $encodedCss;
      style.dataset.nanoVariant = '$variant';
      var bFix = document.getElementById('nano-wa-web-mode-banner-fix');
      if (bFix) bFix.remove(); document.documentElement.classList.remove('nano-wa-web-mode'); document.body.classList.remove('nano-web-chat');
      document.documentElement.classList.add('nano-wa-mobile-shell');

      window.__nanoWaMarkPanels = function() {
        var side = document.getElementById('side');
        var main = document.getElementById('main');
        if (!side) return false;
        var directBranch = function(root, target) {
          var n = target;
          while (n && n.parentElement !== root) n = n.parentElement;
          return n;
        };
        var layout = document.querySelector('.two');
        if (!layout) {
          layout = side;
          while (layout && layout.parentElement && layout.parentElement !== document.body) {
            if (main && layout.contains(main)) break;
            layout = layout.parentElement;
          }
        }
        if (!layout) return false;
        var sideHost = directBranch(layout, side);
        var mainHost = main ? directBranch(layout, main) : null;
        if (!mainHost) {
          mainHost = layout.querySelector('div:has([data-testid="intro-panel"])') ||
                     layout.querySelector('section[data-testid="intro-panel"]')?.parentElement;
        }
        layout.classList.add('nano-wa-layout');
        if (sideHost) sideHost.classList.add('nano-wa-list-host');
        if (mainHost && mainHost !== sideHost) mainHost.classList.add('nano-wa-conversation-host');
        return true;
      };

      window.__nanoWaEnsureBackButton = function() {
        var h = document.querySelector('#main header');
        if (!h || document.getElementById('nano-wa-header-back-btn')) return;
        var btn = document.createElement('button');
        btn.id = 'nano-wa-header-back-btn';
        btn.setAttribute('aria-label', 'Volver');
        btn.innerHTML = '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 19 5 12 12 5"></polyline></svg>';
        btn.onclick = function(e) {
          if (e) { e.stopPropagation(); e.preventDefault(); }
          window.__nanoWaBackToList();
        };
        h.insertBefore(btn, h.firstChild);
      };

      window.__nanoWaBackToList = function() {
        window.__nanoWaForceList = true;
        document.body.classList.remove('nano-view-chat');
        document.body.classList.add('nano-view-list');
        var backBtn = document.querySelector('#main header span[data-icon="back"]') ||
                      document.querySelector('#main header button[aria-label="Back"]');
        if (backBtn) backBtn.click();
        else window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27 }));
        if (window.flutter_inappwebview?.callHandler) {
          window.flutter_inappwebview.callHandler('WhatsAppNavEvent', { isChatOpen: false });
        }
      };

      window.__nanoWaMarkPanels();
      return true;
    })();
    ''';
  }

  /// Observador de mutaciones del DOM para sincronizar navegación y toques.
  static String buildObserverScript() {
    final scrollerScript = WhatsAppWebTouchScripts.buildTouchScrollerScript();
    return '''
    (function() {
      if (window.__nanoWaObserver?.disconnect) window.__nanoWaObserver.disconnect();
      if (window.__nanoWaObserverTimer) clearTimeout(window.__nanoWaObserverTimer);
      var lastState = null, scheduled = false, lastScan = 0;
      $scrollerScript

      var checkActive = function() {
        var now = Date.now();
        if (window.__nanoWaMarkPanels && now - lastScan >= 1000) {
          window.__nanoWaMarkPanels();
          lastScan = now;
        }
        var main = document.getElementById('main');
        // Un chat está activo si #main existe con header/footer (incluso si está grabando voz sin contenteditable)
        var isChat = !window.__nanoWaForceList &&
            !!(main && (main.querySelector('header') || main.querySelector('footer') || main.querySelector('[contenteditable="true"]')));
        document.body.classList.toggle('nano-view-chat', isChat);
        document.body.classList.toggle('nano-view-list', !isChat);
        if (isChat && window.__nanoWaEnsureBackButton) window.__nanoWaEnsureBackButton();
        var pane = document.getElementById('pane-side');
        if (pane && !pane.__nanoTouchBound) {
          $scrollerScript
        }
        if (isChat === lastState) return;
        lastState = isChat;
        if (window.flutter_inappwebview?.callHandler) {
          window.flutter_inappwebview.callHandler('WhatsAppNavEvent', { isChatOpen: isChat });
        }
      };

      var obs = new MutationObserver(function() {
        if (scheduled) return;
        scheduled = true;
        window.__nanoWaObserverTimer = setTimeout(function() {
          scheduled = false;
          checkActive();
        }, 80);
      });
      var target = document.getElementById('app') || document.body;
      if (target) obs.observe(target, { childList: true, subtree: true });

      if (window.__nanoWaClickRoot && window.__nanoWaClickHandler) {
        window.__nanoWaClickRoot.removeEventListener('click', window.__nanoWaClickHandler, true);
      }
      window.__nanoWaClickRoot = target;
      window.__nanoWaClickHandler = function(ev) {
        if (window.__nanoIsScrolling) return;
        var pane = document.getElementById('pane-side');
        var row = ev.target?.closest?.('[role="listitem"], [role="row"], [data-testid="cell-frame-container"]');
        if (!pane || !row || !pane.contains(row)) return;
        window.__nanoWaForceList = false;
        lastState = null;
        setTimeout(checkActive, 0);
        setTimeout(checkActive, 120);
        setTimeout(checkActive, 300);
      };
      target.addEventListener('click', window.__nanoWaClickHandler, true);

      window.__nanoWaObserver = obs;
      checkActive();
    })();
    ''';
  }

  static String buildSuspendObserverScript() =>
      WhatsAppWebNavigationScripts.buildSuspendObserverScript();

  static String buildRestoreOriginalScript() =>
      WhatsAppWebNavigationScripts.buildRestoreOriginalScript();

  static String buildBackPressScript() =>
      WhatsAppWebNavigationScripts.buildBackPressScript();
}
