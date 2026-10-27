import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'whatsapp_web_observer_access.dart';

/// Detecta el panel ya utilizable sin esperar imágenes y recursos secundarios.
abstract final class WhatsAppWebReadiness {
  static Future<bool> check(InAppWebViewController controller) async =>
      await WhatsAppWebObserverAccess.read(controller, r'''
(() => location.origin === 'https://web.whatsapp.com'
  && Boolean(document.querySelector('#pane-side,[data-testid="chat-list"]'))
  && Boolean(localStorage.getItem('last-wid-md')))()
''') ==
      true;
}
