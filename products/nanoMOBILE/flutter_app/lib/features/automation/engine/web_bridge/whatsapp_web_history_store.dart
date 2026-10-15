/// QUÉ HACE:
/// Persiste y pagina el historial de WhatsApp Web a través de la capa nativa unificada.
///
/// CÓMO FUNCIONA:
/// - Envia lotes de hasta 200 mensajes al MethodChannel 'webHistoryAppend'.
/// - Registra la cobertura histórica en 'conversation_coverage' para que el constructor de contexto
///   sepa qué ventanas temporales están observadas continuamente.
/// - Pagina mensajes mediante 'webHistoryPage' con soporte de cursor determinista.
///
/// POR QUÉ:
/// Conecta la captura de WhatsApp Web con la fuente canónica única ('canonical_messages'),
/// asegurando idempotencia, trazabilidad de huecos y cumplimiento de Clean Architecture.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import '../messaging/canonical_message.dart';
import '../messaging/canonical_message_store.dart';
import 'whatsapp_web_history_message.dart';

final class WhatsAppWebHistoryStore {
  static const _channel = MethodChannel('com.nanoai/automation_store');

  Future<void> append(
    String account,
    String chat,
    String alias,
    List<WhatsAppWebHistoryMessage> rows,
  ) async {
    // El contrato nativo acepta 200 por transacción, no 200 por historial.
    // Guarda todas las filas expuestas; cada lote confirma su persistencia real.
    for (var start = 0; start < rows.length; start += 200) {
      final end = (start + 200).clamp(0, rows.length);
      final batch = rows.sublist(start, end);
      final written = await _channel.invokeMethod<int>('webHistoryAppend', {
        'account': account,
        'chat': chat,
        'alias': alias,
        'rows': batch.map((r) => r.toStored()).toList(),
      });
      if (written != batch.length) {
        throw StateError('No se confirmó el historial');
      }

      // Registra cobertura temporal en canonical_messages coverage
      if (batch.isNotEmpty) {
        final times = batch.map((r) => r.atMs).where((t) => t > 0).toList();
        if (times.isNotEmpty) {
          times.sort();
          final targetConvId = alias.isNotEmpty ? alias : chat;
          unawaited(
            canonicalMessageStore.recordCoverage(
              conversationId: targetConvId,
              provider: CanonicalMessageProvider.whatsappWeb,
              fromMs: times.first,
              toMs: times.last,
              gapBefore: false,
            ),
          );
        }
      }
    }
  }

  Future<({List<WhatsAppWebHistoryMessage> rows, bool hasMore})> page(
    String account,
    String alias, {
    WhatsAppWebHistoryMessage? before,
  }) async {
    final data = await _channel
        .invokeMapMethod<String, dynamic>('webHistoryPage', {
          'account': account,
          'alias': alias,
          if (before != null) 'beforeMs': before.atMs,
          if (before != null) 'beforeId': before.eventId,
        });
    if (data == null) throw StateError('Historial local no disponible');
    return (
      rows: (data['rows'] as List)
          .map(
            (r) => WhatsAppWebHistoryMessage.fromStored(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList(),
      hasMore: data['hasMore'] == true,
    );
  }
}
