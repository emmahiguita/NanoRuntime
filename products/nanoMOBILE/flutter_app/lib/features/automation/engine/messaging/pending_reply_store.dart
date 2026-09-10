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
  Future<void> dismiss(String id);
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

  @override
  Future<List<PendingReply>> allPending() async {
    await init();
    final now = DateTime.now();
    return _inMemory.values
        .where(
          (r) =>
              r.status == PendingReplyStatus.pending &&
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
    await init();
    final item = _inMemory[id];
    if (item != null) {
      _inMemory[id] = item.copyWith(status: PendingReplyStatus.approved);
      await _persist();
    }
  }

  @override
  Future<void> dismiss(String id) async {
    await init();
    final item = _inMemory[id];
    if (item != null) {
      _inMemory[id] = item.copyWith(status: PendingReplyStatus.dismissed);
      await _persist();
    }
  }

  @override
  Future<void> updateDraftText(String id, String newText) async {
    await init();
    final item = _inMemory[id];
    if (item != null) {
      _inMemory[id] = item.copyWith(draftText: newText);
      await _persist();
    }
  }

  @override
  Future<void> markSent(String id) async {
    await init();
    final item = _inMemory[id];
    if (item != null) {
      _inMemory[id] = item.copyWith(status: PendingReplyStatus.sent);
      await _persist();
    }
  }

  @override
  Future<void> markFailed(String id) async {
    await init();
    final item = _inMemory[id];
    if (item != null) {
      _inMemory[id] = item.copyWith(status: PendingReplyStatus.failed);
      await _persist();
    }
  }
}
