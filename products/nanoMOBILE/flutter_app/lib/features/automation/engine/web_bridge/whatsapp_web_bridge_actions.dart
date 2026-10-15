/// Métodos auxiliares de vinculación, captura y recarga para WhatsApp Web.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'whatsapp_web_js_bridge.dart';

abstract final class WhatsAppWebBridgeActions {
  static Future<bool> switchToPhoneLinking(
    InAppWebViewController? controller,
  ) async {
    if (controller == null) return false;
    final result = await controller.evaluateJavascript(
      source: WhatsAppWebJsBridge.switchToPhoneCodeScript,
    );
    return result == true;
  }

  static Future<Uint8List?> captureScreen(
    InAppWebViewController? controller,
  ) async {
    if (controller == null) return null;
    try {
      return await controller.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getPairingCode(
    InAppWebViewController? controller,
  ) async {
    if (controller == null) return null;
    final res = await controller.evaluateJavascript(
      source: WhatsAppWebJsBridge.extractPairingCodeScript,
    );
    return res?.toString();
  }

  static Future<void> reloadSession(
    InAppWebViewController? controller,
  ) async {
    await controller?.reload();
  }
}
