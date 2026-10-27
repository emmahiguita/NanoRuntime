/// Lee datos del DOM real; no usa APIs privadas ni cambia mensajes.
library;

abstract final class WhatsAppWebHistoryScripts {
  /// Mantiene los espacios entre palabras: nombres distintos no deben coincidir.
  static String normalizeTitle(String value) => value
      .replaceAll(RegExp(r'[\uFE0E\uFE0F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  // WhatsApp dibuja los emojis como <img alt="…">: textContent los pierde y un
  // título como "🤜🏻👍fonszo" nunca coincidía con el encabezado del chat.
  static const domHelpers = r'''
  function txt(n) {
    var s = '';
    n.childNodes.forEach(function(c) {
      if (c.nodeType === 3) s += c.nodeValue;
      else if (c.nodeType === 1) s += c.tagName === 'IMG' ? (c.getAttribute('alt') || '') : txt(c);
    });
    return s;
  }
  function norm(v) { return String(v || '').replace(/[\uFE0E\uFE0F]/g, '').replace(/\s+/g, ' ').trim().toLowerCase(); }
  function header() {
    var n = document.querySelector('[data-testid="conversation-info-header-chat-title-name"]')
      || document.querySelector('#main header span[dir="auto"]');
    return n ? (n.getAttribute('title') || txt(n)).trim() : '';
  }
''';

  /// Apertura rápida: solo cuenta y encabezado, sin recorrer ni copiar mensajes.
  static const selection =
      '''
(function() {
  if (location.origin !== 'https://web.whatsapp.com') return JSON.stringify({});
$domHelpers
  var account = localStorage.getItem('last-wid-md');
  try { account = JSON.parse(account); } catch (_) { account = null; }
  return JSON.stringify({title:header(), accountId:typeof account === 'string' ? account : ''});
})()
''';

  /// Conserva fecha y dirección del mensaje; no las infiere del resumen.
  static const read =
      '''
(function() {
  if (location.origin !== 'https://web.whatsapp.com') return JSON.stringify({});
$domHelpers
  var account = localStorage.getItem('last-wid-md');
  try { account = JSON.parse(account); } catch (_) { account = null; }
  var rows = [], seen = new Set(), chat = null, skipped = 0;
  document.querySelectorAll('#main [data-pre-plain-text]').forEach(function(meta) {
    var host = meta.closest('[data-id]'), id = host && host.getAttribute('data-id');
    var match = id && id.match(/^(true|false)_([^_]+)_/);
    if (!match || seen.has(id)) return;
    seen.add(id);
    if (chat && chat !== match[2]) { skipped++; return; }
    chat = match[2];
    var text = Array.from(meta.querySelectorAll('.selectable-text,[data-testid="selectable-text"]'))
      .filter(function(n) { return n.closest('[data-pre-plain-text]') === meta; })
      .map(function(n) { return txt(n); }).join('\\n');
    if (!text.trim()) { skipped++; return; }
    rows.push({eventId:id, body:text, metadata:meta.getAttribute('data-pre-plain-text'),
      isSelf:match[1] === 'true'});
  });
  var e2eBanner = document.querySelector('#main [data-testid="encryption-notice"], #main [data-testid="msg-notification-e2e"], #main [data-testid="chat-Initial-encryption-notice"]');
  var reachedStart = Boolean(e2eBanner) && skipped === 0;
  // Solo cuando el aviso de cifrado inicial es visible y no se omitieron nodos se confirma ausencia de hueco previo.
  return JSON.stringify({title:header(),
    accountId:typeof account === 'string' ? account : '', chatId:chat || '',
    rows:rows, skipped:skipped, reachedStart:reachedStart,
    locale:document.documentElement.lang || ''});
})()
''';

  /// Solicita otra página a WhatsApp; no recarga ni pulsa enviar.
  static const earlier = r'''
(function() {
  if (location.origin !== 'https://web.whatsapp.com') return false;
  var main = document.querySelector('#main');
  if (!main) return false;
  var pane = Array.from(main.querySelectorAll('div')).find(function(n) {
    return n.clientHeight > 0 && n.scrollHeight > n.clientHeight + 50
      && /auto|scroll/.test(getComputedStyle(n).overflowY);
  });
  if (!pane) return false;
  pane.scrollTop = Math.max(0, pane.scrollTop - pane.clientHeight * 0.8);
  pane.dispatchEvent(new Event('scroll', {bubbles:true}));
  return true;
})()
''';
}
