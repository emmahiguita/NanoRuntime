import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../infrastructure/browser_scripts.dart';

typedef BrowserMediaTransfer = ({double positionSeconds, bool wasPlaying});

/// Lee el estado del medio visible sin almacenar ni simular reproducción.
abstract final class BrowserMediaTransferReader {
  /// Devuelve `null` cuando la página no contiene un medio compatible.
  static Future<BrowserMediaTransfer?> read(
    InAppWebViewController? controller,
  ) async {
    if (controller == null) return null;
    try {
      final raw = await controller.evaluateJavascript(
        source: BrowserScripts.readMediaStateScript,
      );
      if (raw == null) return null;
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      final position = (decoded['currentTime'] as num?)?.toDouble() ?? 0;
      return (
        positionSeconds: position.isFinite ? position : 0.0,
        wasPlaying: decoded['wasPlaying'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
