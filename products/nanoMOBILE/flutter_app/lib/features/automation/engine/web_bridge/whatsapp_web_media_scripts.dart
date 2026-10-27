// whatsapp_web_media_scripts.dart
//
// QUÉ HACE:
// Scripts DOM verificados para la máquina de estados multimedia de WhatsApp Web.
//
// CÓMO FUNCIONA:
// 1. Verifica que la cuenta vinculada, el JID del destinatario y el título del chat
//    coincidan exactamente antes de cada fase (prepare, stage, commit).
// 2. Inyecta el archivo como Blob/File mediante DataTransfer en el input de adjuntos
//    sin alterar borradores previos ni abrir selectores nativos del sistema.
// 3. Verifica la apertura del modal de previsualización, inserta el caption opcional
//    y realiza un único clic de envío confirmado sobre el botón del preview.
//
// POR QUÉ:
// Completa el Punto 5: ningún envío multimedia se ejecuta a ciegas ni se asume
// entregado sin verificar destino, modal de preview y unicidad del botón de commit.

library;

import 'dart:convert';
import 'whatsapp_web_history_scripts.dart';

abstract final class WhatsAppWebMediaScripts {
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
    if (!phone || !header()) return null;
    return {account:account, chat:chat, phone:phone[1], title:header(), main:main};
  }
  function hasActivePreview() {
    return Boolean(document.querySelector('[data-testid="media-editor"], [data-animate-modal-body="true"] span[data-icon="send"]'));
  }
''';

  /// Fase 1: Verifica identidad del chat y que no exista otro modal de adjunto abierto.
  static String prepare({
    required String phone,
    required String expectedAccount,
  }) =>
      '''
(function() {
$_identity
  var state = snapshot();
  if (!state || state.phone !== ${jsonEncode(phone)} || state.account !== ${jsonEncode(expectedAccount)})
    return JSON.stringify({status:'notExecuted', reason:'Destino o cuenta Web no verificables para multimedia'});
  if (hasActivePreview())
    return JSON.stringify({status:'notExecuted', reason:'Ya existe una previsualización multimedia abierta'});
  var fileInputs = document.querySelectorAll('#main input[type="file"], footer input[type="file"]');
  if (!fileInputs.length)
    return JSON.stringify({status:'notExecuted', reason:'Input de archivo no disponible en el compositor'});
  return JSON.stringify({status:'ready', account:state.account, chat:state.chat, title:state.title});
})()
''';

  /// Fase 2: Carga el archivo en el input de adjuntos verificando invariantes de contexto.
  static String stageBlob({
    required String phone,
    required String account,
    required String chat,
    required String title,
    required String base64Data,
    required String fileName,
    required String mimeType,
  }) =>
      '''
(function() {
$_identity
  var touched = false;
  function result(status, reason) { return JSON.stringify({status:status, reason:reason}); }
  function matches(s) {
    return s && s.account === ${jsonEncode(account)} && s.chat === ${jsonEncode(chat)}
      && s.phone === ${jsonEncode(phone)} && s.title === ${jsonEncode(title)};
  }
  try {
    var state = snapshot();
    if (!matches(state)) return result('contextChanged', 'El chat cambió antes de adjuntar el archivo');
    if (hasActivePreview()) return result('notExecuted', 'Modal de previsualización previo detectado');
    var inputs = document.querySelectorAll('#main input[type="file"], footer input[type="file"]');
    if (!inputs.length) return result('notExecuted', 'Input multimedia no disponible');
    var raw = atob(${jsonEncode(base64Data)});
    var bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    var file = new File([bytes], ${jsonEncode(fileName)}, {type: ${jsonEncode(mimeType)}});
    var dt = new DataTransfer();
    dt.items.add(file);
    var targetInput = inputs[0];
    touched = true;
    targetInput.files = dt.files;
    targetInput.dispatchEvent(new Event('change', {bubbles: true}));
    var after = snapshot();
    if (!matches(after)) return result('contextChanged', 'El contexto cambió tras adjuntar el archivo');
    return result('mediaStaged', 'Archivo cargado en espera del modal de previsualización');
  } catch (_) {
    return result(touched ? 'outcomeUnknown' : 'notExecuted', 'Fallo al preparar el archivo en el DOM');
  }
})()
''';

  /// Fase 3: Verifica el modal de preview, escribe el caption opcional y pulsa enviar una sola vez.
  static String commitPreview({
    required String phone,
    required String account,
    required String chat,
    required String title,
    required String caption,
  }) =>
      '''
(function() {
$_identity
  var touched = false, captionText = ${jsonEncode(caption.trim())};
  function result(status, reason) { return JSON.stringify({status:status, reason:reason}); }
  function matches(s) {
    return s && s.account === ${jsonEncode(account)} && s.chat === ${jsonEncode(chat)}
      && s.phone === ${jsonEncode(phone)} && s.title === ${jsonEncode(title)};
  }
  try {
    var state = snapshot();
    if (!matches(state)) return result('contextChanged', 'El chat subyacente cambió durante la previsualización');
    var editor = document.querySelector('[data-testid="media-editor"], [data-animate-modal-body="true"]');
    if (!editor) return result('waiting', 'El modal de previsualización aún no está listo');
    if (captionText) {
      var capInput = editor.querySelector('div[contenteditable="true"]');
      if (!capInput) return result('incompleteEvidence', 'Campo de comentario no disponible en el preview');
      if (!txt(capInput).trim()) {
        capInput.focus();
        document.execCommand('insertText', false, captionText);
      }
    }
    var sendIcons = editor.querySelectorAll('button[data-testid="media-send"], span[data-icon="send"]');
    var buttons = Array.from(new Set(Array.from(sendIcons).map(function(n) { return n.closest('button') || n.closest('[role="button"]') || n; })));
    if (buttons.length !== 1 || !buttons[0].getClientRects().length)
      return result('waiting', 'Botón de confirmación multimedia aún no disponible');
    touched = true;
    buttons[0].click();
    return result('dispatchedUnverified', 'Envío multimedia confirmado en modal de preview');
  } catch (_) {
    return result(touched ? 'outcomeUnknown' : 'incompleteEvidence', 'Interrupción durante el commit del preview multimedia');
  }
})()
''';
}
