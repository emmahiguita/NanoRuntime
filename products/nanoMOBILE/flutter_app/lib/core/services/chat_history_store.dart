import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

/// Persistencia serializada del historial de Chat.
///
/// SharedPreferences no es la fuente de verdad durante una sesión: recibe
/// snapshots inmutables y ejecuta cada mutación en orden para que `clear()` no
/// pueda ser adelantado por un guardado anterior todavía pendiente.
class ChatHistoryStore {
  static const String _historyKey = 'nanoai_chat_history';

  Future<void> _writeQueue = Future<void>.value();

  Future<List<ChatMessage>> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final messages = <ChatMessage>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(entry)));
        } catch (error) {
          debugPrint('[chat_history] Entrada inválida ignorada: $error');
        }
      }
      return messages;
    } catch (error) {
      debugPrint('[chat_history] Historial no disponible: $error');
      return const [];
    }
  }

  Future<void> save(List<ChatMessage> messages) {
    final snapshot = jsonEncode(
      messages.map((message) => message.toJson()).toList(),
    );
    return _enqueue((prefs) async {
      await prefs.setString(_historyKey, snapshot);
    });
  }

  Future<void> clear() => _enqueue((prefs) async {
    await prefs.remove(_historyKey);
  });

  Future<void> _enqueue(
    Future<void> Function(SharedPreferences prefs) operation,
  ) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await operation(prefs);
      } catch (error) {
        debugPrint('[chat_history] Error de persistencia: $error');
      }
    });
    return _writeQueue;
  }
}
