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
  static const sectionKey = 'automation.pending_replies';
  final AutomationDbStoreClient? _dbClient;
  final Map<String, PendingReply> _inMemory = {};
  bool _loaded = false;

  PendingReplyStore({AutomationDbStoreClient? dbClient}) : _dbClient = dbClient;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final raw = await _dbClient?.section(sectionKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final now = DateTime.now();
        for (final item in list) {
          final reply = PendingReply.fromJson(item as Map<String, dynamic>);
          // Prune expired
          if (now.isBefore(reply.expiresAt)) {
            _inMemory[reply.id] = reply;
          }
        }
      }
    } catch (e) {
      debugPrint('[PendingReplyStore] init error: $e');
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    try {
      final now = DateTime.now();
      // TTL cleanup on persist
      _inMemory.removeWhere((_, r) => now.isAfter(r.expiresAt));
      final list = _inMemory.values.map((r) => r.toJson()).toList();
      await _dbClient?.putSection(sectionKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PendingReplyStore] persist error: $e');
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
    _inMemory[id] = item.copyWith(status: newStatus);
    await _persist();
    return true;
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
    _inMemory[reply.id] = reply;
    await _persist();
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
