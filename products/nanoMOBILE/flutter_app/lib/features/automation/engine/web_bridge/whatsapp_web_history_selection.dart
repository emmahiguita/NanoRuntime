/// Localiza un hilo real, incluso fuera del listado virtualizado; nunca pulsa enviar.
library;

import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'whatsapp_web_history_scripts.dart';
import 'whatsapp_web_observer_access.dart';

abstract final class WhatsAppWebHistorySelection {
  /// Espera una selección confirmada por el encabezado, no solo por el evento click.
  static Future<Map<dynamic, dynamic>> read(
    InAppWebViewController controller,
    String title,
    bool Function() cancelled, {
    bool metadataOnly = false,
  }) async {
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final expected = WhatsAppWebHistoryScripts.normalizeTitle(title);
    var searched = false;
    try {
      for (var attempt = 0; attempt < 20 && !cancelled(); attempt++) {
        final raw = await WhatsAppWebObserverAccess.read(
          controller,
          _select
              .replaceAll('__TITLE__', jsonEncode(title))
              .replaceAll('__TOKEN__', jsonEncode(token)),
        );
        final state = _decode(raw)['state'];
        if (state == 'ambiguous') {
          throw StateError('Hay varios chats con ese nombre');
        }
        if (state == 'unavailable') {
          throw StateError('La sesión Web no permite localizar el chat');
        }
        if (state == 'search_busy') {
          throw StateError('La búsqueda Web está en uso');
        }
        searched |= state == 'searching';
        if (state == 'ready' || state == 'opening') {
          final data = _decode(
            await WhatsAppWebObserverAccess.read(
              controller,
              metadataOnly
                  ? WhatsAppWebHistoryScripts.selection
                  : WhatsAppWebHistoryScripts.read,
            ),
          );
          if (WhatsAppWebHistoryScripts.normalizeTitle(
                '${data['title'] ?? ''}',
              ) ==
              expected) {
            return data;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (cancelled()) return const {};
      throw StateError(
        searched
            ? 'WhatsApp no encontró un chat único con ese nombre'
            : 'WhatsApp no confirmó la apertura del chat',
      );
    } finally {
      // Restaura solo nuestra búsqueda; no toca borradores ni consultas de otro lector.
      try {
        await WhatsAppWebObserverAccess.read(
          controller,
          _restore.replaceAll('__TOKEN__', jsonEncode(token)),
        );
      } catch (_) {
        /* El WebView puede haberse desmontado al cerrar el detalle. */
      }
    }
  }

  static Map<dynamic, dynamic> _decode(Object? raw) {
    final value = raw is String ? jsonDecode(raw) : raw;
    return value is Map ? value : const {};
  }

  static const _select =
      '''
(function() {
  function result(state) { return JSON.stringify({state:state}); }
  if (location.origin !== 'https://web.whatsapp.com') return result('unavailable');
${WhatsAppWebHistoryScripts.domHelpers}
  var title = __TITLE__, token = __TOKEN__, expected = norm(title);
  if (norm(header()) === expected) return result('ready');
  // WhatsApp cambia con frecuencia los roles internos. La fila observable es
  // la misma que usa el feed y el título puede estar en `title` o en el texto.
  var pane = document.querySelector('#pane-side') || document.querySelector('[data-testid="chat-list"]');
  if (!pane) return result('unavailable');
  var rowSelector = '[role="listitem"],[role="row"],[data-testid="cell-frame-container"]';
  var rows = Array.from(pane.querySelectorAll(rowSelector)).filter(function(row) {
    var parent = row.parentElement && row.parentElement.closest(rowSelector);
    if (parent && pane.contains(parent)) return false;
    var titled = Array.from(row.querySelectorAll('[title]')).map(function(n) {
      return n.getAttribute('title') || '';
    });
    var firstLine = String(row.innerText || '').split('\\n').find(function(v) { return v.trim(); }) || '';
    return titled.some(function(v) { return norm(v) === expected; }) || norm(firstLine) === expected;
  });
  if (rows.length > 1) return result('ambiguous');
  if (rows.length === 1) {
    // La primera gridcell es el avatar/selector y no abre el hilo en la
    // versión actual de WhatsApp. La columna 2 contiene el control principal.
    var target = rows[0].querySelector('[role="gridcell"][aria-colindex="2"]')
      || rows[0].querySelector('[role="gridcell"]:nth-of-type(2)')
      || rows[0].querySelector('[title]')
      || rows[0];
    target.dispatchEvent(new PointerEvent('pointerdown', {
      bubbles:true, cancelable:true, pointerId:1, pointerType:'mouse', isPrimary:true
    }));
    target.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, cancelable:true, view:window}));
    target.dispatchEvent(new PointerEvent('pointerup', {
      bubbles:true, cancelable:true, pointerId:1, pointerType:'mouse', isPrimary:true
    }));
    target.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, cancelable:true, view:window}));
    target.click();
    return result('opening');
  }
  // Siempre acotado al panel lateral para no confundirlo con el compositor.
  var side = document.querySelector('#side') || pane.parentElement;
  var search = side && (side.querySelector('[data-testid="chat-list-search-container"] input[role="textbox"]')
    || side.querySelector('input[role="textbox"]')
    || side.querySelector('[contenteditable="true"][role="textbox"]'));
  if (!search || search.disabled) return result('unavailable');
  var owned = window.__nanoWaHistorySearch;
  if ((owned && owned.token !== token) || (!owned && search.value)) return result('search_busy');
  if (!owned) {
    window.__nanoWaHistorySearch = {token:token, query:title, previous:search.value};
    search.focus();
    if (search instanceof HTMLInputElement) {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(search, title);
    } else {
      search.textContent = title;
    }
    search.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'insertText', data:title}));
  }
  return result('searching');
})()
''';

  static const _restore = r'''
(function() {
  if (location.origin !== 'https://web.whatsapp.com') return false;
  var owned = window.__nanoWaHistorySearch;
  if (!owned || owned.token !== __TOKEN__) return false;
  var side = document.querySelector('#side') || document.querySelector('#pane-side');
  var search = side && (side.querySelector('[data-testid="chat-list-search-container"] input[role="textbox"]')
    || side.querySelector('input[role="textbox"]')
    || side.querySelector('[contenteditable="true"][role="textbox"]'));
  var current = search instanceof HTMLInputElement ? search.value : (search && search.textContent || '');
  if (search && current === owned.query) {
    if (search instanceof HTMLInputElement) {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(search, owned.previous);
    } else {
      search.textContent = owned.previous;
    }
    search.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'insertText', data:owned.previous}));
  }
  delete window.__nanoWaHistorySearch;
  return true;
})()
''';
}
