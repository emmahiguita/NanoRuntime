import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

/// Persistencia serializada del historial de Chat.
///
/// Fuente de verdad: archivo `chat_history.json` escrito con
/// `writeAsStringSync(flush: true)` — la escritura síncrona con flush real
/// sobrevive al SIGKILL de ColorOS (BFGS por presión de memoria), donde el
/// apply() async de SharedPreferences perdía la última respuesta generada.
/// SharedPreferences queda solo como legado de lectura (migración).
class ChatHistoryStore {
  static const String _legacyPrefsKey = 'nanoai_chat_history';
  static const String _fileName = 'chat_history.json';

  File _file;

  ChatHistoryStore() : _file = File('chat_history.json');

  /// Resuelve el archivo real la primera vez (necesita contexto de directorio).
  Future<void> _ensureFile() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/$_fileName');
  }

  Future<List<ChatMessage>> restore() async {
    try {
      await _ensureFile();
      if (await _file.exists()) {
        final raw = await _file.readAsString();
        return _decode(raw);
      }
      // Migración: historial previo guardado en SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPrefsKey);
      if (legacy != null && legacy.isNotEmpty) {
        return _decode(legacy);
      }
      return const [];
    } catch (error) {
      debugPrint('[chat_history] Historial no disponible: $error');
      return const [];
    }
  }

  List<ChatMessage> _decode(String raw) {
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
  }

  /// Guardado SÍNCRONO con flush: el dato llega a disco antes de devolver.
  /// 2 KB de JSON cuestan ~5 ms — costo trivial frente a perder la última
  /// respuesta por un kill del sistema.
  Future<void> save(List<ChatMessage> messages) async {
    try {
      await _ensureFile();
      final snapshot = jsonEncode(
        messages.map((message) => message.toJson()).toList(),
      );
      _file.writeAsStringSync(snapshot, flush: true);
    } catch (error) {
      debugPrint('[chat_history] Error de persistencia: $error');
    }
  }

  Future<void> clear() async {
    try {
      await _ensureFile();
      if (await _file.exists()) {
        await _file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyPrefsKey);
    } catch (error) {
      debugPrint('[chat_history] Error de persistencia: $error');
    }
  }
}
