// QUÉ HACE: centraliza trazas de recepción y entrega sin copiar contenido privado.
// CÓMO: registra origen, fase, paquete, hora, capacidad de respuesta y causa técnica.
// POR QUÉ: permite seguir un evento por Android y Flutter sin guardar texto o remitentes.
library;

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import '../notifications/notification_object.dart';

final class NotificationEventTrace {
  // Identifica los paquetes de WhatsApp cuyos mensajes necesitan correlación.
  static bool isWhatsApp(NotificationObject event) =>
      event.packageName == 'com.whatsapp' ||
      event.packageName == 'com.whatsapp.w4b';

  // Registra una transición simple con valores internos no sensibles.
  static void stage(
    String name, {
    String source = 'none',
    String outcome = 'seen',
    String detail = '',
  }) {
    debugPrint(
      '[notifications] stage=$name source=$source outcome=$outcome $detail',
    );
  }

  // Resume el filtro por lote; no imprime la notificación ni el nombre del chat.
  static void batch(String source, int total, int admitted) {
    debugPrint(
      '[notifications] stage=decode source=$source events=$total admitted=$admitted filtered=${total - admitted}',
    );
  }

  // Expone datos operativos de un mensaje y permite correlacionar horas Android/Flutter.
  static void event(NotificationObject event, String source, String state) {
    final at = event.messageTimestamp > 0
        ? event.messageTimestamp
        : event.postTime;
    debugPrint(
      '[notifications] stage=$state source=$source pkg=${event.packageName} at=$at chars=${event.interpretableText.length} conversation=${event.isConversationEvent} canReply=${event.canReply}',
    );
  }

  // Añade tipo y stack técnico, sin el texto de la excepción que podría traer contenido.
  static void failure(
    String stage,
    String source,
    Object error,
    StackTrace stack,
  ) {
    debugPrint(
      '[notifications] stage=$stage source=$source outcome=error cause=${error.runtimeType}',
    );
    debugPrintStack(stackTrace: stack);
  }
}
