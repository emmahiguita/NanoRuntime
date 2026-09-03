/// CAP-ROUTER-01 — CapabilityIntent: la intención SEMÁNTICA que el agente
/// necesita satisfacer, expresada en términos del dominio (conversación,
/// texto aprobado), nunca en términos de vía de ejecución.
///
/// Solo existen intents con EFECTO EXTERNO: son los únicos que necesitan
/// decidir una ruta de ejecución. Las lecturas locales (resumir, buscar,
/// historial) no pasan por el CapabilityResolver: no despachan ningún
/// efecto y no deben pagar el costo de un router (sin código muerto).
///
/// Quien decide la vía es [CapabilityResolver]; este archivo solo declara
/// QUÉ se quiere hacer. Un intent jamás menciona RemoteInput, gestos ni
/// coordenadas.
library;

import '../messaging/conversation_key.dart';
import '../messaging/reply_capability.dart';

sealed class CapabilityIntent {
  const CapabilityIntent();

  /// Descripción corta y factual para logs y evidencia (nunca para decidir).
  String describe();
}

/// Enviar una respuesta a UNA conversación exacta. El texto ya pasó por la
/// cadena de gobernanza; aquí llega aprobado.
final class ReplyIntent extends CapabilityIntent {
  const ReplyIntent({
    required this.conversationKey,
    required this.draftText,
    this.capabilityRef,
  });

  final ConversationKey conversationKey;
  final String draftText;

  /// Referencia a la capacidad RemoteInput si el intent nace de una
  /// notificación observada. Null cuando el intent nace de un flujo con la
  /// conversación abierta en pantalla (GUI).
  final ReplyCapabilityRef? capabilityRef;

  @override
  String describe() =>
      'reply(${conversationKey.channel}/${conversationKey.appPackage}) '
      '${capabilityRef == null ? 'sinRemoteInput' : 'conRemoteInput'}';
}

/// Abrir una conversación exacta en su app. Efecto externo de navegación:
/// abre la app (intent) y navega hasta la conversación (GUI) solo si la
/// conversación objetivo no está ya en pantalla.
final class OpenConversationIntent extends CapabilityIntent {
  const OpenConversationIntent(this.conversationKey);

  final ConversationKey conversationKey;

  @override
  String describe() =>
      'openConversation(${conversationKey.channel}/'
      '${conversationKey.appPackage})';
}
