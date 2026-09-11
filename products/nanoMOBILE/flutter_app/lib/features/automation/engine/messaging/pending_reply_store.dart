/// WA-DRAFT-INBOX-01 — Almacén durable de borradores pendientes (Modo Sugerencias).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../storage/automation_db_store_client.dart';
import 'pending_reply.dart';

abstract interface class PendingReplyRepository {
  Future<List<PendingReply>> allPending();
  Future<void> save(PendingReply reply);
  Future<void> approve(String id);
  Future<void> beginDispatch(String id);
  Future<void> dismiss(String id);
  Future<void> markContextChanged(String id);
  Future<void> markSuperseded(String id);
  Future<void> markExpired(String id);
  Future<void> updateDraftText(String id, String newText);
  Future<void> markSent(String id);
  Future<void> markFailed(String id);
}

final class PendingReplyStore implements PendingReplyRepository {
  static const sectionKey = 'pending_replies';
  final AutomationDbStoreClient? _dbClient;
  final Map<String, PendingReply> _inMemory = {};
  bool _loaded = false;
  bool _loadFailed = false;

  PendingReplyStore({AutomationDbStoreClient? dbClient}) : _dbClient = dbClient;

  Future<void> init() async {
    if (_loaded) return;
    try {
      var raw = await _dbClient?.section(sectionKey);
      if (raw == null || raw.isEmpty) {
        raw = await _dbClient?.section('automation.pending_replies');
      }
      var reconciledAny = false;
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final now = DateTime.now();
        for (final item in list) {
          final reply = PendingReply.fromJson(item as Map<String, dynamic>);
          // Prune expired
          if (now.isBefore(reply.expiresAt)) {
            // WA-PROCESS-DEATH: Si la app murió mientras estaba en dispatching,
            // NUNCA revertir a pending automáticamente (riesgo de duplicación si RemoteInput
            // ya fue aceptado). Transicionar de forma honesta a outcomeUnknown.
            if (reply.status == PendingReplyStatus.dispatching) {
              debugPrint(
                '[PendingReplyStore] Process death detectado para borrador ${reply.id}. '
                'Reconciliando a outcomeUnknown (sin reintento ciego).',
              );
              _inMemory[reply.id] = reply.copyWith(
                status: PendingReplyStatus.outcomeUnknown,
              );
              reconciledAny = true;
            } else {
              _inMemory[reply.id] = reply;
            }
          }
        }
      }
      _loaded = true;
      _loadFailed = false;
      if (reconciledAny) {
        await _persist();
      }
    } catch (e) {
      debugPrint('[PendingReplyStore] init error: $e');
      _loadFailed = true;
      _loaded = false;
      rethrow;
    }
  }

  Future<void> _persist() async {
    if (_loadFailed) {
      throw StateError(
        '[PendingReplyStore] Bloqueo fail-closed: init falló previamente, '
        'se rechaza sobrescribir la sección $sectionKey',
      );
    }
    final now = DateTime.now();
    // TTL cleanup on persist
    _inMemory.removeWhere((_, r) => now.isAfter(r.expiresAt));
    final list = _inMemory.values.map((r) => r.toJson()).toList();
    final client = _dbClient;
    if (client != null) {
      final ok = await client.putSection(sectionKey, jsonEncode(list));
      if (!ok) {
        throw StateError(
          '[PendingReplyStore] Fallo crítico al persistir sección $sectionKey en SQLite',
        );
      }
    }
  }

  Future<bool> _transition(String id, PendingReplyStatus newStatus) async {
    await init();
    final item = _inMemory[id];
    if (item == null) return false;
    if (!item.canTransitionTo(newStatus)) {
      debugPrint(
        '[PendingReplyStore] Transición inválida rechazada: '
        '${item.status.name} -> ${newStatus.name} para borrador $id',
      );
      return false;
    }
    final previous = item;
    _inMemory[id] = item.copyWith(status: newStatus);
    try {
      await _persist();
      return true;
    } catch (e) {
      _inMemory[id] = previous; // Rollback transaccional en memoria
      rethrow;
    }
  }

  @override
  Future<List<PendingReply>> allPending() async {
    await init();
    final now = DateTime.now();
    return _inMemory.values
        .where(
          (r) =>
              (r.status == PendingReplyStatus.pending ||
                  r.status == PendingReplyStatus.approved) &&
              now.isBefore(r.expiresAt),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> save(PendingReply reply) async {
    await init();
    final previous = _inMemory[reply.id];
    _inMemory[reply.id] = reply;
    try {
      await _persist();
    } catch (e) {
      if (previous != null) {
        _inMemory[reply.id] = previous;
      } else {
        _inMemory.remove(reply.id);
      }
      rethrow;
    }
  }

  @override
  Future<void> approve(String id) async {
    await _transition(id, PendingReplyStatus.approved);
  }

  @override
  Future<void> beginDispatch(String id) async {
    await _transition(id, PendingReplyStatus.dispatching);
  }

  @override
  Future<void> dismiss(String id) async {
    await _transition(id, PendingReplyStatus.dismissed);
  }

  @override
  Future<void> markContextChanged(String id) async {
    await _transition(id, PendingReplyStatus.contextChanged);
  }

  @override
  Future<void> markSuperseded(String id) async {
    await _transition(id, PendingReplyStatus.superseded);
  }

  @override
  Future<void> markExpired(String id) async {
    await _transition(id, PendingReplyStatus.expired);
  }

  @override
  Future<void> updateDraftText(String id, String newText) async {
    await init();
    final item = _inMemory[id];
    if (item != null && item.isActionable) {
      var sanitized = newText.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (sanitized.length > 2000) {
        sanitized = sanitized.substring(0, 2000).trim();
      }
      _inMemory[id] = item.copyWith(draftText: sanitized);
      await _persist();
    }
  }

  @override
  Future<void> markSent(String id) async {
    await _transition(id, PendingReplyStatus.sent);
  }

  @override
  Future<void> markFailed(String id) async {
    await _transition(id, PendingReplyStatus.failed);
  }
}
