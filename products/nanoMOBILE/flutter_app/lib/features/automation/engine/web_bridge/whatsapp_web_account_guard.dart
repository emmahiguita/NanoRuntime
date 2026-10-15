import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'whatsapp_web_history_scripts.dart';
import 'whatsapp_web_observer_access.dart';

/// Comprueba la cuenta ANTES de que un lector seleccione un hilo por su etiqueta.
abstract final class WhatsAppWebAccountGuard {
  static Future<void> check(
    InAppWebViewController controller,
    String expected,
  ) async {
    final raw = await WhatsAppWebObserverAccess.read(
      controller,
      WhatsAppWebHistoryScripts.read,
    );
    final decoded = raw is String ? jsonDecode(raw) : raw;
    final actual = decoded is Map ? '${decoded['accountId'] ?? ''}' : '';
    if (expected.isEmpty || actual != expected) {
      throw StateError('La cuenta Web no corresponde a este chat');
    }
  }
}
