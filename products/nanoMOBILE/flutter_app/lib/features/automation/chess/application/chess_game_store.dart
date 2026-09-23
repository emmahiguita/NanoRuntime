/// CHESS-GAME-STORE — Persistencia local de partidas de ajedrez en Nano AI.
///
/// **QUÉ HACE:**
/// Administra el ciclo de vida, guardado y recuperación de partidas de ajedrez
/// activas o archivadas por ID de conversación.
///
/// **CÓMO FUNCIONA:**
/// Mantiene un caché en memoria de acceso síncrono (< 1 ms) y respalda de manera
/// atómica en `SharedPreferences` con clave canónica `nano_chess_games_v1`.
///
/// **POR QUÉ:**
/// Asegura que tras un reinicio de la app o reinicio del sistema operativo Android,
/// las partidas no se pierdan y los jugadores puedan continuar su partida exactamente
/// donde la dejaron.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/chess_game_session.dart';

abstract interface class ChessGameStore {
  Future<void> load();
  ChessGameSession? getGame(String conversationId);
  Future<void> saveGame(ChessGameSession session);
  Future<void> deleteGame(String conversationId);
  List<ChessGameSession> listActiveGames();
}

final class LocalChessGameStore implements ChessGameStore {
  static const _storageKey = 'nano_chess_games_v1';
  final Map<String, ChessGameSession> _cache = {};
  bool _loaded = false;

  @override
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          try {
            final session = ChessGameSession.fromJson(
              entry.value as Map<String, dynamic>,
            );
            _cache[entry.key] = session;
          } catch (_) {}
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  @override
  ChessGameSession? getGame(String conversationId) {
    return _cache[conversationId];
  }

  @override
  Future<void> saveGame(ChessGameSession session) async {
    _cache[session.conversationId] = session;
    await _persist();
  }

  @override
  Future<void> deleteGame(String conversationId) async {
    _cache.remove(conversationId);
    await _persist();
  }

  @override
  List<ChessGameSession> listActiveGames() {
    return _cache.values.where((g) => !g.status.isGameOver).toList();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        for (final entry in _cache.entries) entry.key: entry.value.toJson(),
      };
      await prefs.setString(_storageKey, jsonEncode(map));
    } catch (_) {}
  }
}

/// Provider singleton del almacén de partidas de ajedrez.
final chessGameStoreProvider = Provider<ChessGameStore>((ref) {
  final store = LocalChessGameStore();
  store.load();
  return store;
});

/// Provider reactivo de la partida activa para una conversación específica.
final activeChessGameProvider =
    StateProvider.family<ChessGameSession?, String>((ref, conversationId) {
      final store = ref.watch(chessGameStoreProvider);
      return store.getGame(conversationId);
    });
