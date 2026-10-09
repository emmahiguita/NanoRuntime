import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Puente mínimo con Android para capacidades que WebView no expone en Dart.
class BrowserWebCompatibilityBridge {
  const BrowserWebCompatibilityBridge();

  static const _channel = MethodChannel('com.nanoai/browser_compatibility');

  /// Cambia juntos el User-Agent clásico y sus Client Hints antes de navegar.
  Future<bool> setDesktopIdentity(
    InAppWebViewController controller, {
    required bool enabled,
  }) async {
    try {
      final viewId = controller.getViewId()?.toString();
      if (viewId == null || viewId.isEmpty) return false;
      return await _channel.invokeMethod<bool>('setDesktopIdentity', {
            'viewId': viewId,
            'enabled': enabled,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Solicita al sistema solo cámara/micrófono pedidos por la página aprobada.
  Future<bool> requestMediaPermissions({
    required bool camera,
    required bool microphone,
  }) async {
    if (!camera && !microphone) return true;
    try {
      return await _channel.invokeMethod<bool>('requestMediaPermissions', {
            'camera': camera,
            'microphone': microphone,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
