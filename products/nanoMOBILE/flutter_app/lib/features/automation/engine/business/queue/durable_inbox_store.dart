// durable_inbox_store.dart
//
// QUÉ HACE:
// Almacén persistente en SQLite para registrar claves de idempotencia de mensajes entrantes.
//
// CÓMO FUNCIONA:
// - Verifica si un eventId ya fue procesado antes de iniciar el flujo comercial.
// - Registra los nuevos eventos con retención de 48 horas (TTL).
//
// POR QUÉ:
// Asegura idempotencia estricta que sobrevive a reinicios del sistema y reenvíos de la red.

library;

import 'dart:convert';
import '../../storage/automation_db_store_client.dart';
import 'durable_inbox_entry.dart';

class DurableInboxStore {
  const DurableInboxStore();

  static const String _section = 'business_durable_inbox';
  static const Duration _retention = Duration(hours: 48);

  Future<Map<String, DurableInboxEntry>> _loadAll() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(_section);
      if (raw == null || raw.isEmpty) return {};
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return map.map(
        (k, v) => MapEntry(
          k,
          DurableInboxEntry.fromJson((v as Map).cast<String, dynamic>()),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<bool> _saveAll(Map<String, DurableInboxEntry> entries) async {
    try {
      final map = entries.map((k, v) => MapEntry(k, v.toJson()));
      return await AutomationDbStoreClient.instance.putSection(
        _section,
        jsonEncode(map),
      );
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el mensaje ya fue registrado como procesado.
  Future<bool> isProcessed(String eventId) async {
    if (eventId.isEmpty) return false;
    final all = await _loadAll();
    final entry = all[eventId];
    if (entry == null) return false;

    // Verificar si expiró
    if (DateTime.now().difference(entry.receivedAt) > _retention) {
      all.remove(eventId);
      await _saveAll(all);
      return false;
    }
    return true;
  }

  /// Registra un mensaje como procesado.
  Future<void> markProcessed({
    required String eventId,
    required String conversationId,
    required String content,
  }) async {
    if (eventId.isEmpty) return;
    final all = await _loadAll();

    // Limpieza de entradas viejas
    final now = DateTime.now();
    all.removeWhere((_, e) => now.difference(e.receivedAt) > _retention);

    all[eventId] = DurableInboxEntry(
      eventId: eventId,
      conversationId: conversationId,
      contentHash: content.hashCode.toString(),
      receivedAt: now,
    );

    await _saveAll(all);
  }
}
