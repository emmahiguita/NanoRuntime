/// Acceso al mismo WebView nativo retenido, sin recrearlo ni recargar su URL.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract final class WhatsAppWebObserverAccess {
  /// Un commit irreversible se invoca una sola vez. Un resultado null no
  /// permite repetir: el primer script podría haber hecho el clic sin ACK.
  static Future<Object?> executeOnce(
    InAppWebViewController controller,
    String source,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return controller.evaluateJavascript(source: source);
    }
    final viewId = controller.getViewId();
    if (viewId == null) throw StateError('WebView Android sin identidad');
    final raw =
        await MethodChannel(
          'com.pichillilorenzo/flutter_inappwebview_$viewId',
        ).invokeMethod<Object?>('evaluateJavascript', {
          'source': source,
          'contentWorld': null,
        });
    return raw is String ? jsonDecode(raw) : raw;
  }

  /// Los scripts del feed devuelven true como confirmación de ejecución.
  /// En flutter_inappwebview_android 1.1.3, dispose(isKeepAlive: true)
  /// conserva el WebView/handlers pero deja channel=null en el controlador
  /// Dart antiguo. Por eso null no confirma que el script se haya ejecutado.
  static Future<bool> evaluate(
    InAppWebViewController controller,
    String source,
  ) async {
    final result = await read(controller, source);
    return result == true || (result is String && result == 'true');
  }

  /// Lee el resultado real por el mismo canal, incluso con la ruta desmontada.
  static Future<Object?> read(
    InAppWebViewController controller,
    String source,
  ) async {
    final result = await controller.evaluateJavascript(source: source);
    if (result != null) return result;
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final viewId = controller.getViewId();
    if (viewId == null) return null;
    // Invoca el canal nativo existente de la versión integrada del plugin.
    // No registra otro handler, no cambia cookies y no crea una segunda sesión.
    final raw =
        await MethodChannel(
          'com.pichillilorenzo/flutter_inappwebview_$viewId',
        ).invokeMethod<Object?>('evaluateJavascript', {
          'source': source,
          'contentWorld': null,
        });
    return raw is String ? jsonDecode(raw) : raw;
  }
}
