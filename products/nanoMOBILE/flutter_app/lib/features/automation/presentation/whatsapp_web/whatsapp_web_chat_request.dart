import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../engine/web_bridge/whatsapp_web_history_selection.dart';
import '../../engine/web_bridge/whatsapp_web_operation_lock.dart';
import '../../engine/web_bridge/whatsapp_web_account_guard.dart';

/// Abre solo el chat solicitado en la cuenta observada; no envía ni invoca APIs privadas.
abstract final class WhatsAppWebChatRequest {
  static Future<void> open(
    InAppWebViewController controller,
    String title,
    String alias,
    bool Function() cancelled,
  ) => WhatsAppWebOperationLock.run(() async {
    final parts = alias.startsWith('waweb:')
        ? alias.substring(6).split('/')
        : <String>[];
    if (parts.length != 2 || parts.first.isEmpty || title.trim().isEmpty) {
      throw StateError('Este chat no tiene una cuenta Web identificada');
    }
    final expectedAccount = Uri.decodeComponent(parts.first);
    await WhatsAppWebAccountGuard.check(controller, expectedAccount);
    if (cancelled()) return;
    final data = await WhatsAppWebHistorySelection.read(
      controller,
      title,
      cancelled,
      metadataOnly: true,
    );
    if (cancelled()) return;
    if ('${data['accountId'] ?? ''}' != expectedAccount) {
      throw StateError('La cuenta Web no corresponde a este chat');
    }
    // Algunas versiones actuales ya no exponen `data-id` en los mensajes.
    // La apertura queda autenticada por cuenta + encabezado exacto; `chatId`
    // es metadato opcional y no debe bloquear el WebView oficial.
    // El visor original de WhatsApp carga fotos/audio/video con su propia sesión.
    // No se extraen URLs firmadas ni se etiqueta un preview como archivo descargado.
  });
}
