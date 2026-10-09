// durable_outbox_queue.dart
//
// QUÉ HACE:
// Cola persistente transaccional en SQLite para mensajes salientes (Durable Outbox).
//
// CÓMO FUNCIONA:
// - Almacena las respuestas generadas antes de entregarlas al canal físico.
// - Provee métodos para encolar, obtener mensajes listos para envío y marcar estados.
//
// POR QUÉ:
// Asegura la semántica 'at-least-once' con reintentos exponenciales ante fallas de red.

library;

import 'dart:convert';
import '../../storage/automation_db_store_client.dart';
import 'durable_outbox_message.dart';

class DurableOutboxQueue {
  const DurableOutboxQueue();

  static const String _section = 'business_durable_outbox';

  Future<List<DurableOutboxMessage>> _loadAll() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(_section);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list
          .map((item) => DurableOutboxMessage.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> _saveAll(List<DurableOutboxMessage> messages) async {
    try {
      final list = messages.map((m) => m.toJson()).toList();
      return await AutomationDbStoreClient.instance.putSection(
        _section,
        jsonEncode(list),
      );
    } catch (_) {
      return false;
    }
  }

  /// Encola un nuevo mensaje para entrega garantizada.
  Future<void> enqueue(DurableOutboxMessage message) async {
    final all = await _loadAll();
    all.add(message);
    await _saveAll(all);
  }

  /// Retorna los mensajes que están listos para enviarse (status queued y timestamp cumplido).
  Future<List<DurableOutboxMessage>> getPendingMessages() async {
    final all = await _loadAll();
    final now = DateTime.now();
    return all.where((m) => m.status == OutboxStatus.queued && m.nextAttemptAt.isBefore(now)).toList();
  }

  /// Marca un mensaje como enviado con éxito (lo remueve de la cola).
  Future<void> markDispatched(String messageId) async {
    final all = await _loadAll();
    all.removeWhere((m) => m.id == messageId);
    await _saveAll(all);
  }

  /// Registra un fallo de envío y recalcula el reintento.
  Future<void> recordFailure(String messageId, String error) async {
    final all = await _loadAll();
    final index = all.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final current = all[index];
      all[index] = current.withNextRetry(error);
      await _saveAll(all);
    }
  }
}
