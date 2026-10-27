import 'dart:async';

import '../messaging/canonical_message.dart';
import '../messaging/canonical_message_store.dart';

/// Función de transporte para invocar una herramienta MCP (`whatsapp_get_changes`).
typedef McpToolCaller =
    Future<Map<String, Object?>> Function(
      String toolName,
      Map<String, Object?> args,
    );

/// Coordinador sin duplicados que sincroniza deltas de WhatsApp MCP hacia
/// [CanonicalMessageStore] y construye el bloque compacto `<WHATSAPP PENDIENTES>`
/// para que el modelo local LiteRT-LM conozca qué chats esperan respuesta.
///
/// - **QUÉ HACE:** Conecta las herramientas MCP (`whatsapp_get_changes`) con el
///   almacén canónico SQLite en Kotlin y formatea los chats sin responder.
/// - **CÓMO FUNCIONA:** Usa un candado `single-flight` ([_inFlight]) para evitar
///   ejecuciones concurrentes, lee el cursor actual con `getSyncCursor`, pide
///   solo eventos nuevos y los guarda en una sola transacción SQLite.
/// - **POR QUÉ:** Así evitamos bases de datos paralelas, condiciones de carrera
///   y consumo innecesario de tokens en el prompt del modelo.
class WhatsAppMcpDeltaSync {
  const WhatsAppMcpDeltaSync._();

  static const String defaultStreamKey = 'whatsapp_mcp:main';
  static final _inFlight = <String, Future<bool>>{};

  /// Sincroniza en segundo plano los cambios pendientes usando [callTool].
  ///
  /// - **QUÉ HACE:** Avanza el cursor incremental en SQLite sin duplicar filas.
  /// - **CÓMO FUNCIONA:** Si ya hay una sincronización corriendo, reutiliza el
  ///   mismo `Future` (`single-flight`).
  /// - **POR QUÉ:** Evita bloqueos y llamadas redundantes cuando llegan varias
  ///   notificaciones seguidas.
  static Future<bool> syncWithCaller(
    McpToolCaller callTool, {
    String stream = defaultStreamKey,
    int limit = 100,
  }) {
    final existing = _inFlight[stream];
    if (existing != null) return existing;
    final future = _runSync(callTool, stream: stream, limit: limit);
    _inFlight[stream] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[stream], future)) {
        _inFlight.remove(stream);
      }
    });
  }

  /// Ejecuta la lectura del cursor, invocación MCP y escritura transaccional.
  static Future<bool> _runSync(
    McpToolCaller callTool, {
    required String stream,
    required int limit,
  }) async {
    try {
      final cursorSeq = await canonicalMessageStore.getSyncCursor(stream);
      final response = await callTool('whatsapp_get_changes', {
        'after': cursorSeq,
        'limit': limit,
      });
      final eventsRaw = response['events'];
      if (eventsRaw is! List) return false;

      final nextCursor =
          (response['next_cursor'] as num?)?.toInt() ?? cursorSeq;
      final snapshotSeq = (response['snapshot_seq'] as num?)?.toInt() ?? 0;

      final messages = <CanonicalMessage>[];
      for (final item in eventsRaw) {
        if (item is! Map) return false;
        final map = Map<String, Object?>.from(item);
        final msgMap = map['message'];
        if (msgMap is! Map) return false;
        final msg = Map<String, Object?>.from(msgMap);
        final text = (msg['text']?.toString() ?? '').trim();
        // No adelanta el cursor de eventos multimedia/no soportados que aún
        // no se han normalizado: el gateway deberá entregar un lote compatible.
        if (text.isEmpty) return false;

        final chatId = (msg['chat_id']?.toString() ?? '').trim();
        final msgId = (msg['id']?.toString() ?? '').trim();
        if (chatId.isEmpty || msgId.isEmpty) return false;

        final fromMe = msg['from_me'] == true;
        final tsMs = (msg['timestamp_ms'] as num?)?.toInt() ?? 0;
        if (tsMs <= 0) return false;
        messages.add(
          CanonicalMessage.observed(
            conversationId:
                'whatsapp-mcp/${Uri.encodeComponent(stream)}/${Uri.encodeComponent(chatId)}',
            provider: CanonicalMessageProvider.whatsappMcp,
            providerMessageId: msgId,
            direction: fromMe
                ? CanonicalMessageDirection.outbound
                : CanonicalMessageDirection.inbound,
            sender: (msg['sender_name']?.toString() ?? chatId).trim(),
            body: text,
            occurredAtMs: tsMs,
            rawMetadata: {
              'accountId': stream,
              'sourceChatId': chatId,
              'source': 'whatsapp_mcp',
              'evidenceLevel': 'source_observed',
              'complete': true,
            },
          ),
        );
      }

      if (messages.isEmpty && nextCursor <= cursorSeq) return false;
      return canonicalMessageStore.applyMcpDeltaBatch(
        stream: stream,
        nextCursor: nextCursor,
        snapshotSeq: snapshotSeq,
        messages: messages,
      );
    } catch (_) {
      return false;
    }
  }

  /// Construye un resumen ultracompacto de conversaciones entrantes sin
  /// responder para inyectarlo en `<CONTEXTO DEL TURNO>`.
  ///
  /// - **QUÉ HACE:** Devuelve hasta [limit] chats pendientes formateados en
  ///   una línea cada uno (máximo ~100 tokens).
  /// - **CÓMO FUNCIONA:** Consulta `canonicalMessageStore.listPendingConversations`
  ///   y recorta textos largos a 70 caracteres.
  /// - **POR QUÉ:** Permite que el usuario pregunte "¿quién me escribió?" o
  ///   "¿qué tengo pendiente en WhatsApp?" y el modelo responda con datos reales.
  static Future<String> buildPendingSummaryBlock({int limit = 4}) async {
    final pending = await canonicalMessageStore.listPendingConversations(
      limit: limit,
    );
    if (pending.isEmpty) return '';
    final lines = <String>['WhatsApp pendientes de responder:'];
    for (final item in pending) {
      final sender = (item['sender'] ?? item['conversationId'] ?? 'Contacto')
          .toString()
          .trim();
      final body = (item['body'] ?? '').toString().trim();
      if (body.isEmpty) continue;
      final preview = body.length <= 70 ? body : '${body.substring(0, 67)}...';
      lines.add('- $sender: "$preview"');
    }
    return lines.length > 1 ? lines.join('\n') : '';
  }
}
