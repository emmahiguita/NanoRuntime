// tiktok_web_scripts.dart
// QUÉ HACE: JavaScript que opera la bandeja real de TikTok Web adaptada en
//   VERTICAL (pantalla completa Lista/Chat) y HORIZONTAL (doble panel lado a lado).
// CÓMO: selectores data-e2e + CSS adaptativo responsive con viewport móvil.

import 'dart:convert';

/// Viewport móvil nativo reafirmado ante mutaciones de la SPA.
const String deviceWidthViewportScript = """
(function() {
  const content = 'width=device-width, initial-scale=1, maximum-scale=5, user-scalable=yes, viewport-fit=cover';
  const apply = () => {
    const head = document.head || document.documentElement;
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) { vp = document.createElement('meta'); vp.name = 'viewport'; head.prepend(vp); }
    if (vp.getAttribute('content') !== content) vp.setAttribute('content', content);
  };
  apply();
  new MutationObserver(apply).observe(document.head || document.documentElement, {
    childList: true, subtree: true, attributes: true, attributeFilter: ['content', 'name'],
  });
})();
""";

/// CSS y observador de orientación para vertical y horizontal sin solapamiento.
const String panelLayoutCssScript = """
(function() {
  const css = `
    #main-content-messages {
      flex: 1 1 auto !important; width: calc(100vw - 72px) !important;
      max-width: calc(100vw - 72px) !important; min-width: 0 !important;
      margin: 0 !important; padding: 0 !important; overflow: hidden !important;
      display: flex !important; flex-direction: row !important;
    }
    [class*="DivChatBox"] {
      height: 100vh !important; max-height: 100vh !important; display: flex !important;
      flex-direction: column !important; overflow: hidden !important; min-width: 0 !important;
    }
    [data-e2e="dm-new-message-list"], [class*="DivChatMain"] {
      flex: 1 1 auto !important; min-height: 0 !important; overflow-y: auto !important;
    }
    [class*="DivChatBottom"] {
      width: 100% !important; position: sticky !important; bottom: 0 !important;
      z-index: 20 !important; background: #121212 !important; flex-shrink: 0 !important;
    }
    [class*="DivMessageInputAndSendButton"] { width: 100% !important; }
    [class*="DivInputAreaContainer"] { flex: 1 1 auto !important; min-width: 140px !important; }
    [class*="DivEditorContainer"] { width: 100% !important; }
    .nano-chat-back-btn {
      display: none; align-items: center; justify-content: center; width: 32px;
      height: 32px; margin-right: 8px; border-radius: 50%;
      background: rgba(255, 255, 255, 0.12); color: #fff; cursor: pointer; border: none; font-size: 18px;
    }
    /* VERTICAL (< 600px): un solo panel activo a la vez */
    html.nano-portrait:not(.nano-chat-open) [class*="DivChatBox"],
    html:not(.nano-landscape):not(.nano-chat-open) [class*="DivChatBox"] { display: none !important; }
    html.nano-portrait:not(.nano-chat-open) [class*="DivV3AnimLeftColumn"],
    html:not(.nano-landscape):not(.nano-chat-open) [class*="DivV3AnimLeftColumn"] {
      width: 100% !important; max-width: 100% !important; min-width: 0 !important;
      display: flex !important; flex-direction: column !important; height: 100vh !important;
    }
    html.nano-portrait.nano-chat-open [class*="DivV3AnimLeftColumn"],
    html:not(.nano-landscape).nano-chat-open [class*="DivV3AnimLeftColumn"] { display: none !important; }
    html.nano-portrait.nano-chat-open [class*="DivChatBox"],
    html:not(.nano-landscape).nano-chat-open [class*="DivChatBox"] {
      width: 100% !important; max-width: 100% !important; min-width: 0 !important;
      display: flex !important; flex-direction: column !important; height: 100vh !important;
    }
    html.nano-portrait.nano-chat-open .nano-chat-back-btn,
    html:not(.nano-landscape).nano-chat-open .nano-chat-back-btn { display: inline-flex !important; }
    /* HORIZONTAL (>= 600px): dos paneles lado a lado */
    html.nano-landscape [class*="DivV3AnimLeftColumn"] {
      width: 280px !important; min-width: 280px !important; max-width: 300px !important;
      display: flex !important; flex-direction: column !important; height: 100vh !important;
      border-right: 1px solid rgba(255, 255, 255, 0.12) !important;
    }
    html.nano-landscape [class*="DivChatBox"] {
      flex: 1 1 auto !important; width: calc(100% - 280px) !important; min-width: 0 !important;
      display: flex !important; flex-direction: column !important; height: 100vh !important;
    }
  `;
  let st = document.getElementById('nano-panel-fix');
  if (!st) {
    st = document.createElement('style'); st.id = 'nano-panel-fix';
    (document.head || document.documentElement).appendChild(st);
  }
  st.textContent = css;

  const updateOrient = () => {
    const isLand = window.innerWidth >= 600;
    document.documentElement.classList.toggle('nano-landscape', isLand);
    document.documentElement.classList.toggle('nano-portrait', !isLand);
  };
  window.addEventListener('resize', updateOrient);
  window.addEventListener('orientationchange', updateOrient);
  updateOrient();

  const addBackBtn = () => {
    const header = document.querySelector('[class*="DivChatHeader"]');
    if (header && !header.querySelector('.nano-chat-back-btn')) {
      const btn = document.createElement('button');
      btn.className = 'nano-chat-back-btn'; btn.innerHTML = '‹';
      btn.onclick = (e) => { e.stopPropagation(); document.documentElement.classList.remove('nano-chat-open'); };
      header.prepend(btn);
    }
  };
  document.addEventListener('click', (e) => {
    if (e.target.closest('[data-e2e="dm-new-conversation-item"]')) {
      document.documentElement.classList.add('nano-chat-open');
      setTimeout(addBackBtn, 400);
    }
  }, true);
  addBackBtn();
  return 'ok';
})()
""";

/// Alterna la clase de vista de chat.
String buildSetChatViewScript({required bool chatOpen}) =>
    "(() => { document.documentElement.classList.toggle('nano-chat-open', ${chatOpen ? 'true' : 'false'}); return 'view:' + (${chatOpen ? "'chat'" : "'list'"}); })()";

String _json(Object? value) => jsonEncode(value);

/// Lee la lista de conversaciones.
String buildReadConversationsScript() => """
(() => {
  const items = Array.from(document.querySelectorAll('[data-e2e="dm-new-conversation-item"]'));
  return JSON.stringify(items.map((el, index) => {
    const name = el.querySelector('[data-e2e="dm-new-conversation-nickname"]');
    const unread = el.querySelector('[data-e2e="dm-new-conversation-unread"]');
    return {
      index,
      name: (name?.innerText || '').trim().split('\\n')[0].slice(0, 80),
      unread: (unread?.innerText || '').replace(/\\D/g, ''),
    };
  }));
})()
""";

/// Abre la conversación por índice.
String buildOpenConversationScript(int index) =>
    "(() => { const items = document.querySelectorAll('[data-e2e=\"dm-new-conversation-item\"]'); const target = items[$index]; if (!target) return JSON.stringify({ ok: false, reason: 'index fuera de rango' }); target.click(); return JSON.stringify({ ok: true }); })()";

/// Cabecera del chat abierto.
String buildReadActiveChatScript() => """
(() => {
  const name = document.querySelector('[data-e2e="dm-new-chat-nickname"]');
  const uid = document.querySelector('[data-e2e="chat-uniqueid"]');
  return JSON.stringify({
    name: (name?.innerText || '').trim().slice(0, 80),
    uniqueId: (uid?.innerText || '').trim().slice(0, 40),
  });
})()
""";

/// Mensajes del chat abierto.
String buildReadMessagesScript() =>
    "(() => { const items = Array.from(document.querySelectorAll('[data-e2e=\"dm-new-chat-item\"]')); return JSON.stringify(items.map((el) => ({ text: (el.innerText || '').trim().replace(/\\s+/g, ' ') })).filter((m) => m.text.length > 0).slice(-30)); })()";

/// Badge de no leídos.
String buildUnreadBadgeScript() =>
    "(() => { const badge = document.querySelector('[data-e2e=\"dm-total-unread-count\"]'); return JSON.stringify({ unread: (badge?.innerText || '').replace(/\\D/g, '') }); })()";

/// Envía mensaje por el editor Draft.js real.
String buildSendReplyScript(String text) => """
(() => {
  const text = ${_json(text)};
  const editor = document.querySelector('[data-e2e="dm-new-input-editor"] [contenteditable="true"]')
    || document.querySelector('.public-DraftEditor-content');
  if (!editor) return JSON.stringify({ ok: false, reason: 'editor no encontrado' });
  editor.focus();
  document.execCommand('insertText', false, text);
  const inserted = (editor.innerText || '').trim();
  if (!inserted) return JSON.stringify({ ok: false, reason: 'inserción rechazada por el editor' });
  editor.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
  return JSON.stringify({ ok: true, inserted: inserted.slice(0, 60) });
})()
""";
