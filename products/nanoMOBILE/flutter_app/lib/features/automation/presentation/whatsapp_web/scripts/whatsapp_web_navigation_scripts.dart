// whatsapp_web_navigation_scripts.dart
//
// QUÉ HACE:
// Genera los scripts JavaScript para la navegación de retroceso (Back) y la
// restauración de la vista original de escritorio de WhatsApp Web.
//
// CÓMO FUNCIONA:
// - buildBackPressScript: Simula la pulsación de Escape o acciona el botón nativo de chat
//   para cerrar la conversación activa y volver a la lista principal de contactos.
// - buildRestoreOriginalScript: Remueve estilos inyectados, clases CSS y restaura el meta-viewport
//   original para regresar conmutativamente a la vista web de escritorio sin recargar.
// - buildSuspendObserverScript: Desconecta los observadores MutationObserver y libera escuchadores.
//
// POR QUÉ:
// Aplica Clean Architecture y principio de Responsabilidad Única (SRP), manteniendo cada archivo
// estrictamente por debajo del límite de 200 líneas de código y facilitando el mantenimiento.

import 'whatsapp_web_rail_scripts.dart';
import 'whatsapp_web_touch_scripts.dart';

class WhatsAppWebNavigationScripts {
  const WhatsAppWebNavigationScripts._();

  /// Retorna a la lista de chats simulando la pulsación de Escape o el botón nativo de chat.
  static String buildBackPressScript() {
    return '''
    window.__nanoWaForceList = true;
    document.body.classList.remove('nano-view-chat', 'nano-web-chat');
    document.body.classList.add('nano-view-list');
    var b = document.querySelector('#main header span[data-icon="back"]') ||
            document.querySelector('#main header button[aria-label="Back"]');
    if (b) b.click();
    else window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27 }));
    if (window.__nanoWaRailAdapter?.apply) setTimeout(window.__nanoWaRailAdapter.apply, 50);
    ''';
  }

  /// Restaura la vista web de escritorio original eliminando los overrides inyectados.
  static String buildRestoreOriginalScript() {
    final railAdapter = WhatsAppWebRailScripts.buildRailAdapterScript();
    final touchScroller = WhatsAppWebTouchScripts.buildTouchScrollerScript();
    return '''
    var vp = document.querySelector('meta[name="viewport"]');
    var wasChat = document.body.classList.contains('nano-view-chat') && !!document.getElementById('main');
    document.body.classList.remove('nano-view-list', 'nano-view-chat', 'nano-web-chat');
    if (wasChat) document.body.classList.add('nano-web-chat');
    document.documentElement.classList.remove('nano-wa-mobile-shell');
    document.documentElement.classList.add('nano-wa-web-mode');
    window.__nanoWaForceList = false;
    window.__nanoWaMarkPanels = null;
    if (vp) delete vp.dataset.nanoVariant;
    document.querySelectorAll('.nano-wa-layout, .nano-wa-list-host, .nano-wa-conversation-host').forEach(function(n) {
      n.classList.remove('nano-wa-layout', 'nano-wa-list-host', 'nano-wa-conversation-host');
    });
    var s = document.getElementById('nano-wa-responsive-style');
    if (s) s.remove();
    if (!vp) {
      vp = document.createElement('meta');
      vp.name = 'viewport';
      document.head.appendChild(vp);
    }
    vp.setAttribute('content', 'width=device-width, initial-scale=0.88, minimum-scale=0.5, maximum-scale=5, user-scalable=yes');
    $railAdapter
    document.querySelectorAll('*').forEach(function(el) { if (el.scrollLeft > 0) el.scrollLeft = 0; });
    window.scrollTo(0, 0);
    var appEl = document.getElementById('app') || document.body;
    if (window.__nanoWebClickHandler) appEl.removeEventListener('click', window.__nanoWebClickHandler, true);
    window.__nanoWebClickHandler = function(ev) {
      if (!document.documentElement.classList.contains('nano-wa-web-mode') || window.__nanoIsScrolling) return;
      var rail = window.findNavigationRail ? window.findNavigationRail() : document.querySelector('.two > header');
      var backBtn = ev.target?.closest?.('#nano-wa-header-back-btn');
      if ((rail && rail.contains(ev.target)) || backBtn) {
        document.body.classList.remove('nano-web-chat');
        if (window.__nanoWaRailAdapter?.apply) setTimeout(window.__nanoWaRailAdapter.apply, 50);
        return;
      }
      var pane = document.getElementById('pane-side');
      var row = ev.target?.closest?.('[role="listitem"], [role="row"], [data-testid="cell-frame-container"]');
      if (pane && row && pane.contains(row)) {
        setTimeout(function() {
          if (document.getElementById('main')) document.body.classList.add('nano-web-chat');
          if (window.__nanoWaRailAdapter?.apply) window.__nanoWaRailAdapter.apply();
        }, 80);
      }
    };
    appEl.addEventListener('click', window.__nanoWebClickHandler, true);
    $touchScroller
    ''';
  }

  /// Desconexión de observadores para liberar memoria al suspender.
  static String buildSuspendObserverScript() {
    final suspendRail = WhatsAppWebRailScripts.buildSuspendRailAdapterScript();
    final suspendTouch = WhatsAppWebTouchScripts.buildSuspendTouchScript();
    return '''
    if (window.__nanoWaObserver?.disconnect) window.__nanoWaObserver.disconnect();
    if (window.__nanoWaObserverTimer) clearTimeout(window.__nanoWaObserverTimer);
    if (window.__nanoWaClickRoot && window.__nanoWaClickHandler) {
      window.__nanoWaClickRoot.removeEventListener('click', window.__nanoWaClickHandler, true);
    }
    window.__nanoWaObserver = null;
    window.__nanoWaObserverTimer = null;
    $suspendRail
    $suspendTouch
    ''';
  }
}
