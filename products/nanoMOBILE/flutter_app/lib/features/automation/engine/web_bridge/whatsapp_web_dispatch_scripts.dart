/// Verifica cuenta, JID y compositor real antes de un único clic de envío.
/// No abre chats por nombre ni usa interfaces internas de WhatsApp.
library;

import 'dart:convert';
import 'whatsapp_web_history_scripts.dart';

abstract final class WhatsAppWebDispatchScripts {
  /// Comparte la misma lectura de emojis/encabezado que el lector de historial.
  static const _identity =
      '''
${WhatsAppWebHistoryScripts.domHelpers}
  function snapshot() {
    if (location.origin !== 'https://web.whatsapp.com') return null;
    var main = document.querySelector('#main'), account;
    try { account = JSON.parse(localStorage.getItem('last-wid-md')); } catch (_) {}
    if (!main || !main.getClientRects().length || typeof account !== 'string' || !account) return null;
    var peers = new Set();
    main.querySelectorAll('[data-id]').forEach(function(n) {
      var match = (n.getAttribute('data-id') || '').match(/^(true|false)_([^_]+)_/);
      if (match) peers.add(match[2]);
    });
    if (peers.size !== 1) return null;
    var chat = Array.from(peers)[0], phone = chat.match(/^([1-9][0-9]{7,14})@(c\\.us|s\\.whatsapp\\.net)\$/);
    var inputs = main.querySelectorAll('footer div[contenteditable="true"][data-tab="10"]');
    if (!phone || inputs.length !== 1 || !header()) return null;
    return {account:account, chat:chat, phone:phone[1], title:header(), main:main, input:inputs[0]};
  }
  function draftText(n) {
    return String(n.innerText || txt(n)).replace(/\\r\\n/g, '\\n').replace(/\\u00a0/g, ' ').trim();
  }
''';

  /// Solo captura evidencia; no enfoca, escribe, selecciona ni envía.
  static String prepare(String phone, String expectedAccount) =>
      '''
(function() {
$_identity
  var state = snapshot();
  if (!state || state.phone !== ${jsonEncode(phone)} || state.account !== ${jsonEncode(expectedAccount)})
    return JSON.stringify({status:'notExecuted', reason:'Destino o cuenta Web no verificables'});
  if (txt(state.input).trim() || state.input.querySelector('img')) return JSON.stringify({status:'notExecuted', reason:'Hay un borrador previo; no se modifica'});
  return JSON.stringify({status:'ready', account:state.account, chat:state.chat, title:state.title});
})()
''';

  /// Escribe sin pulsar enviar: React puede actualizar el botón en otro frame.
  static const stageBody = r'''
    if (txt(state.input).trim() || state.input.querySelector('img'))
      return result('notExecuted', 'El compositor contiene otro borrador');
    state.input.focus();
    touched = true;
    if (!document.execCommand('insertText', false, text))
      return result('outcomeUnknown', 'No se confirmó la escritura; no reintentar');
    var after = snapshot();
    if (!matches(after) || after.main !== state.main || after.input !== state.input)
      return result('contextChanged', 'El contexto cambió después de escribir');
    return result('draftPrepared', 'Borrador preparado; todavía no se envió');
''';

  /// Cada espera acredita que NO hubo clic; cualquier resultado incierto termina.
  static const commitBody = r'''
    if (draftText(state.input) !== text.replace(/\r\n/g, '\n').replace(/\u00a0/g, ' ').trim())
      return result('incompleteEvidence', 'El borrador no coincide; no se pulsó enviar');
    var buttons = state.main.querySelectorAll('footer button[data-testid="compose-btn-send"], footer span[data-icon="send"]');
    var targets = Array.from(new Set(Array.from(buttons).map(function(n) { return n.closest('button') || n; })));
    if (targets.length !== 1 || targets[0].disabled || !targets[0].getClientRects().length)
      return result('waiting', 'El botón todavía no está disponible; no se pulsó');
    touched = true;
    targets[0].click();
    return result('dispatchedUnverified', 'Clic único realizado; entrega remota no verificada');
''';

  /// Comparte guardas entre escritura y commit; parámetros escapados como JSON.
  static String operation({
    required String phone,
    required String text,
    required String account,
    required String chat,
    required String title,
    required String body,
  }) =>
      '''
(function() {
$_identity
  var touched = false, text = ${jsonEncode(text)};
  function result(status, reason) { return JSON.stringify({status:status, reason:reason}); }
  function matches(s) {
    return s && s.account === ${jsonEncode(account)} && s.chat === ${jsonEncode(chat)}
      && s.phone === ${jsonEncode(phone)} && s.title === ${jsonEncode(title)};
  }
  try {
    var state = snapshot();
    if (!matches(state)) return result('contextChanged', 'El destino cambió; no se ejecutó esta acción');
$body
  } catch (_) {
    return result(touched ? 'outcomeUnknown' : 'notExecuted', 'Operación Web interrumpida');
  }
})()
''';
}
