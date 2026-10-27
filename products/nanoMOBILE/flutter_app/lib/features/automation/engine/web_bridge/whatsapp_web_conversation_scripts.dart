/// Observa el DOM real y confirma recepción en Flutter antes de deduplicar.
/// Cada temporizador pertenece al observador y se cancela al apagar el feed.
library;

abstract final class WhatsAppWebConversationScripts {
  static const observe = r'''
(function() {
  // Reinstala en el mismo documento: corrige raíces reemplazadas y fuerza snapshot.
  if (window.__nanoWaStopConversations) window.__nanoWaStopConversations();
  if (window.__nanoWaConversationObserver) window.__nanoWaConversationObserver.disconnect();
  clearInterval(window.__nanoWaConversationInterval);
  var stopped = false, sending = false, dirty = false, lastSignature = '', scanTimer = null;
  var rowSelector = '[role="listitem"], [role="row"], [data-testid="cell-frame-container"]';

  function clean(value, length) {
    return String(value || '').replace(/\s+/g, ' ').trim().slice(0, length);
  }
  // Fechas y horas nunca deben convertirse en la vista previa del mensaje.
  function isTimeLabel(value) {
    return /^(ayer|yesterday|lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo|mon|tue|wed|thu|fri|sat|sun|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}:\d{2}(\s?[ap]\.?\s?m\.?)?)$/i.test(value);
  }
  // Lee una fila por chat; los contenedores anidados no son conversaciones nuevas.
  function collect(pane) {
    return Array.from(pane.querySelectorAll(rowSelector)).filter(function(row) {
      var parent = row.parentElement && row.parentElement.closest(rowSelector);
      return !parent || !pane.contains(parent);
    }).slice(0, 80).map(function(row) {
      var lines = String(row.innerText || '').split('\n')
        .map(function(line) { return clean(line, 1000); }).filter(Boolean);
      var titled = Array.from(row.querySelectorAll('[title]')).map(function(node) {
        return clean(node.getAttribute('title'), 1000);
      }).filter(function(value) { return value && !isTimeLabel(value); });
      var title = clean(titled[0] || lines[0], 160);
      if (!title || title === '0') return null;
      var unreadNode = row.querySelector('[aria-label*="unread" i], '
        + '[aria-label*="sin leer" i], [data-testid="icon-unread-count"]');
      var unreadText = clean(unreadNode && unreadNode.textContent, 8);
      var unreadMatch = unreadText.match(/\d+/);
      var unreadCount = unreadMatch ? Number(unreadMatch[0]) : (unreadNode ? 1 : 0);
      var timeLabel = lines.find(isTimeLabel) || '';
      var messageLines = lines.filter(function(line) {
        return line !== title && line !== timeLabel;
      });
      // Retira solo el badge final identificado, no todos los mensajes numéricos.
      if (unreadNode && messageLines[messageLines.length - 1] === unreadText) messageLines.pop();
      var previews = titled.filter(function(value) { return value !== title; });
      var lastMessage = previews[previews.length - 1] || messageLines[messageLines.length - 1] || '';
      return {
        id: title.toLocaleLowerCase().replace(/[^a-z0-9áéíóúüñ]+/gi, '-') || title,
        displayName: title, lastMessage: clean(lastMessage, 1000),
        timeLabel: clean(timeLabel, 40), unreadCount: Math.min(999, unreadCount),
        isGroup: !!row.querySelector('[data-icon="default-group"], [data-icon="group"]')
      };
    }).filter(Boolean);
  }
  // Solo confirma la firma cuando Flutter admite el snapshot; un cambio de
  // switch o un puente aún no listo no debe perder la primera sincronización.
  function scan() {
    if (scanTimer) clearTimeout(scanTimer);
    scanTimer = null;
    if (stopped) return false;
    if (sending) { dirty = true; return false; }
    // La búsqueda puede mostrar contactos sin historial: no son un snapshot
    // de conversaciones y no deben contaminar la lista real de Mensajería.
    var search = document.querySelector('[data-testid="chat-list-search-container"] input');
    if (window.__nanoWaHistorySearch || (search && search.value.trim())) return true;
    var pane = document.querySelector('#pane-side') || document.querySelector('[data-testid="chat-list"]');
    var bridge = window.flutter_inappwebview;
    if (!pane || !bridge || !bridge.callHandler) return false;
    var conversations = collect(pane);
    var account = localStorage.getItem('last-wid-md');
    try { account = JSON.parse(account); } catch (_) { account = null; }
    if (typeof account !== 'string' || !account) return false;
    // Un cambio de cuenta también cambia la firma aunque los títulos coincidan.
    var signature = JSON.stringify([account, conversations]);
    // Un panel vacío o a medio renderizar no significa que los chats se borraron.
    if (!conversations.length) return true;
    if (signature === lastSignature) return true;
    sending = true;
    bridge.callHandler('WhatsAppWebEvent', {
      event: 'conversations_changed', data: { conversations: conversations,
        account: typeof account === 'string' ? account : '' }
    }).then(function(ack) {
      if (stopped) return;
      if (ack && ack.accepted === true) lastSignature = signature;
    }).catch(function() {
      // La firma queda pendiente y podrá reintentarse sin inventar mensajes.
    }).finally(function() {
      sending = false;
      if (!stopped && dirty) { dirty = false; scheduleScan(); }
    });
    return true;
  }
  function scheduleScan() {
    if (!stopped && !scanTimer) scanTimer = setTimeout(scan, 120);
  }
  // El body permanece aunque React sustituya pane-side. Observa atributos de
  // previews además de texto; la actualización normal no espera al sondeo.
  var target = document.body;
  if (!target) return false;
  var observer = new MutationObserver(scheduleScan);
  observer.observe(target, {childList:true, subtree:true, characterData:true,
    attributes:true, attributeFilter:['title', 'aria-label']});
  window.__nanoWaConversationObserver = observer;
  window.__nanoWaConversationInterval = setInterval(scan, 5000);
  window.__nanoWaScanConversations = scan;
  // Apagar libera todo el trabajo propio; conserva cookies, DOM y conexión Web.
  window.__nanoWaStopConversations = function() {
    stopped = true;
    observer.disconnect();
    clearTimeout(scanTimer);
    clearInterval(window.__nanoWaConversationInterval);
    window.__nanoWaConversationObserver = null;
    window.__nanoWaConversationInterval = null;
    window.__nanoWaScanConversations = null;
    window.__nanoWaStopConversations = null;
  };
  scan();
  return true;
})();
''';

  static const stop = r'''
(function() {
  if (window.__nanoWaStopConversations) window.__nanoWaStopConversations();
  if (window.__nanoWaConversationObserver) window.__nanoWaConversationObserver.disconnect();
  clearInterval(window.__nanoWaConversationInterval);
  window.__nanoWaConversationObserver = null;
  window.__nanoWaConversationInterval = null;
  window.__nanoWaScanConversations = null;
  return true;
})();
''';
}
