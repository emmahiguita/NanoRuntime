/// WA-WEB-JS-BRIDGE-01 — Scripts de inyección y comunicación para WhatsApp Web.
///
/// **QUÉ HACE:**
/// Provee el código JavaScript que se inyecta en el InAppWebView de WhatsApp Web
/// para monitorear el estado de la sesión, auto-ajustar el QR y desambiguar la vinculación.
///
/// **CÓMO FUNCIONA:**
/// Inspecciona el DOM de WhatsApp Web, ajusta el viewport y extrae el dataURL del canvas QR
/// emitiendo eventos reactivos hacia Flutter.
///
/// **POR QUÉ:**
/// Garantiza la lectura del QR sin recortar la pantalla y mantiene la arquitectura desacoplada.
library;

final class WhatsAppWebJsBridge {
  const WhatsAppWebJsBridge._();

  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static const String sessionObserverScript = '''
(function() {
  if (window.__nanoWaInjected) return;
  window.__nanoWaInjected = true;

  function notifyFlutter(eventName, data) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('WhatsAppWebEvent', {
        event: eventName,
        data: data || {}
      });
    }
  }

  // Inyectar CSS responsivo para centrar y ampliar el código QR
  try {
    var style = document.createElement('style');
    style.id = 'nano-wa-qr-style';
    style.innerHTML = `
      body { zoom: 0.75 !important; }
      canvas { max-width: 90vw !important; height: auto !important; margin: 0 auto !important; }
      div[data-ref] { display: flex !important; justify-content: center !important; }
    `;
    document.head.appendChild(style);
    
    // Forzar viewport para permitir zoom manual al máximo
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
  } catch(e) {}

  var checkInterval = setInterval(function() {
    var landingContainer = document.querySelector('div[data-ref]');
    var dataRefString = landingContainer ? landingContainer.getAttribute('data-ref') : null;
    var qrCanvas = document.querySelector('canvas[aria-label="Scan this QR code to link a device"]') ||
                   (landingContainer ? landingContainer.querySelector('canvas') : null) ||
                   document.querySelector('canvas');
    var qrImg = landingContainer ? landingContainer.querySelector('img') : null;

    var paneSide = document.querySelector('#pane-side') ||
                   document.querySelector('div[data-testid="chat-list"]');
    if (paneSide) {
      clearInterval(checkInterval);
      try {
        var style = document.getElementById('nano-wa-qr-style');
        if (style) style.remove();
        document.body.style.zoom = '1';
      } catch(e) {}
      notifyFlutter('status_changed', { status: 'connected' });
      return;
    }

    if (qrCanvas || qrImg || dataRefString) {
      if (qrCanvas) {
        try { qrCanvas.scrollIntoView({ block: 'center', behavior: 'instant' }); } catch(e) {}
      }
      var qrDataUrl = null;
      if (qrImg && qrImg.src && qrImg.src.indexOf('data:image') === 0) {
        qrDataUrl = qrImg.src;
      } else if (qrCanvas) {
        try {
          var off = document.createElement('canvas');
          off.width = qrCanvas.width || 264;
          off.height = qrCanvas.height || 264;
          var ctx = off.getContext('2d');
          ctx.drawImage(qrCanvas, 0, 0);
          qrDataUrl = off.toDataURL('image/png');
        } catch(e1) {
          try { qrDataUrl = qrCanvas.toDataURL('image/png'); } catch(e2) {}
        }
      }
      notifyFlutter('status_changed', { status: 'waitingForQr', qrDataUrl: qrDataUrl, qrDataRef: dataRefString });
      return;
    }


    var progress = document.querySelector('progress') ||
                   document.querySelector('[data-testid="visual-loading"]');
    if (progress) {
      notifyFlutter('status_changed', { status: 'syncing' });
    }
  }, 1000);

  notifyFlutter('bridge_ready', { time: Date.now() });
})();
''';

  static const String switchToPhoneCodeScript = '''
(function() {
  try {
    var btn = Array.from(document.querySelectorAll('span, div, button'))
      .find(function(el) {
        var text = (el.innerText || '').toLowerCase();
        return text.indexOf('vincular con el número de teléfono') !== -1 ||
               text.indexOf('link with phone number') !== -1;
      });
    if (btn) {
      btn.click();
      return true;
    }
    return false;
  } catch(e) {
    return false;
  }
})();
''';

  static const String extractPairingCodeScript = '''
(function() {
  try {
    var el = document.querySelector('div[data-pairing-code]') || document.querySelector('[data-testid="pairing-code"]');
    if (el) return el.innerText.trim();
    var all = Array.from(document.querySelectorAll('span, div'));
    for (var i = 0; i < all.length; i++) {
      var txt = (all[i].innerText || '').trim();
      if (/^[A-Z0-9]{4}-[A-Z0-9]{4}\$/.test(txt) || /^[A-Z0-9]{8}\$/.test(txt)) return txt;
    }
    return null;
  } catch(e) { return null; }
})();
''';

  static String buildSendMediaScript({
    required String base64Data,
    required String mimeType,
    required String fileName,
    String? caption,
  }) {
    final cleanCaption = (caption ?? '').replaceAll("'", "\\'");
    return '''
(function() {
  try {
    var byteCharacters = atob('$base64Data');
    var byteNumbers = new Array(byteCharacters.length);
    for (var i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    var byteArray = new Uint8Array(byteNumbers);
    var blob = new Blob([byteArray], { type: '$mimeType' });
    var file = new File([blob], '$fileName', { type: '$mimeType' });

    var fileInput = document.querySelector('input[type="file"]');
    if (fileInput) {
      var dataTransfer = new DataTransfer();
      dataTransfer.items.add(file);
      fileInput.files = dataTransfer.files;
      fileInput.dispatchEvent(new Event('change', { bubbles: true }));

      if ('$cleanCaption'.length > 0) {
        setTimeout(function() {
          var captionInput = document.querySelector('div[contenteditable="true"][data-tab="10"]');
          if (captionInput) {
            captionInput.focus();
            document.execCommand('insertText', false, '$cleanCaption');
          }
        }, 500);
      }
      return JSON.stringify({ success: true, method: 'file_input' });
    }
    return JSON.stringify({ success: false, error: 'FILE_INPUT_NOT_FOUND' });
  } catch (err) {
    return JSON.stringify({ success: false, error: err.toString() });
  }
})();
''';
  }
}
