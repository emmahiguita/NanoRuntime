/// CHESS-REFEREE-SERVICE — Servicio de arbitraje y orquestación de ajedrez en WhatsApp.
///
/// **QUÉ HACE:**
/// Intercepta y procesa comandos y jugadas de ajedrez procedentes de notificaciones
/// o del compositor de mensajes de Nano AI, actualiza el estado y genera respuestas.
///
/// **CÓMO FUNCIONA:**
/// Consulta [ChessGameStore] para obtener la sesión activa, delega la validación
/// y mutación en [ChessRefereeEngine] y persiste de forma inmediata.
///
/// **POR QUÉ:**
/// Actúa como capa de aplicación desacoplada del transporte de notificaciones,
/// garantizando que la misma lógica sirva tanto para WhatsApp como para la UI del móvil.
library;

import '../domain/chess_game_session.dart';
import '../domain/chess_referee_engine.dart';
import 'chess_game_store.dart';

final class ChessRefereeResponse {
  final bool handled;
  final String replyText;
  final ChessGameSession? session;
  final bool isGameOver;

  const ChessRefereeResponse({
    required this.handled,
    required this.replyText,
    this.session,
    this.isGameOver = false,
  });

  static const ChessRefereeResponse notHandled = ChessRefereeResponse(
    handled: false,
    replyText: '',
  );
}

final class ChessRefereeService {
  final ChessGameStore _store;
  final ChessRefereeEngine _engine;

  const ChessRefereeService({
    required ChessGameStore store,
    ChessRefereeEngine engine = const ChessRefereeEngine(),
  })  : _store = store,
        _engine = engine;

  /// Determina si un mensaje entrante debe ser manejado por el árbitro de ajedrez.
  bool shouldHandleMessage({
    required String conversationId,
    required String text,
  }) {
    if (ChessRefereeEngine.isStartCommand(text) ||
        ChessRefereeEngine.isHelpCommand(text)) {
      return true;
    }

    final activeGame = _store.getGame(conversationId);
    if (activeGame == null || activeGame.status.isGameOver) {
      return false;
    }

    return ChessRefereeEngine.isBoardCommand(text) ||
        ChessRefereeEngine.isResignCommand(text) ||
        ChessRefereeEngine.isDrawCommand(text) ||
        ChessRefereeEngine.isPotentialMove(text);
  }

  /// Procesa el mensaje entrante y devuelve la respuesta correspondiente.
  Future<ChessRefereeResponse> processMessage({
    required String conversationId,
    required String senderJid,
    required String senderName,
    required String text,
    String ownerName = 'Dueño',
    bool isGroup = false,
  }) async {
    final cleanText = text.trim();

    // 1. Ayuda
    if (ChessRefereeEngine.isHelpCommand(cleanText)) {
      return ChessRefereeResponse(
        handled: true,
        replyText: ChessRefereeEngine.helpText(),
      );
    }

    // 2. Iniciar nueva partida
    if (ChessRefereeEngine.isStartCommand(cleanText)) {
      // Si ya hay una activa, preguntar o reiniciar
      final active = _store.getGame(conversationId);
      if (active != null && !active.status.isGameOver) {
        // Si el usuario fuerza '!ajedrez' o 'iniciar ajedrez', reiniciamos
      }

      String whiteJid = senderJid;
      String blackJid = isGroup ? '' : 'owner_jid';
      String whiteName = senderName.isNotEmpty ? senderName : 'Jugador 1';
      String blackName = isGroup ? 'Oponente' : ownerName;

      final session = _engine.startNewGame(
        conversationId: conversationId,
        whitePlayerJid: whiteJid,
        blackPlayerJid: blackJid,
        whitePlayerName: whiteName,
        blackPlayerName: blackName,
      );

      await _store.saveGame(session);

      final initialMsg =
          '♟️ *¡Partida de Ajedrez Iniciada!*\n'
          '⚪ Blancas: *$whiteName*\n'
          '⚫ Negras: *$blackName*\n\n'
          '${ChessRefereeEngine.formatBoardMessage(session: session)}';

      return ChessRefereeResponse(
        handled: true,
        replyText: initialMsg,
        session: session,
      );
    }

    // 3. Comandos sobre partida activa
    final activeGame = _store.getGame(conversationId);
    if (activeGame == null || activeGame.status.isGameOver) {
      return ChessRefereeResponse.notHandled;
    }

    // Ver tablero
    if (ChessRefereeEngine.isBoardCommand(cleanText)) {
      final msg = ChessRefereeEngine.formatBoardMessage(session: activeGame);
      return ChessRefereeResponse(
        handled: true,
        replyText: msg,
        session: activeGame,
      );
    }

    // Rendirse
    if (ChessRefereeEngine.isResignCommand(cleanText)) {
      final result = _engine.resign(
        session: activeGame,
        playerJid: senderJid,
      );
      if (result.updatedSession != null) {
        await _store.saveGame(result.updatedSession!);
      }
      return ChessRefereeResponse(
        handled: true,
        replyText: result.message,
        session: result.updatedSession,
        isGameOver: true,
      );
    }

    // Tablas
    if (ChessRefereeEngine.isDrawCommand(cleanText)) {
      final updated = activeGame.copyWith(
        status: ChessGameStatus.draw,
        winner: 'draw',
      );
      await _store.saveGame(updated);
      return ChessRefereeResponse(
        handled: true,
        replyText: '🤝 *¡Tablas acordadas!* La partida ha terminado en empate.\n\nEnvía "!ajedrez" para comenzar otra.',
        session: updated,
        isGameOver: true,
      );
    }

    // Si es un grupo y aún no se definió el jugador de Negras, el primer rival en mover o responder toma las Negras
    ChessGameSession gameToPlay = activeGame;
    if (gameToPlay.blackPlayerJid.isEmpty && senderJid != gameToPlay.whitePlayerJid) {
      gameToPlay = gameToPlay.copyWith(
        blackPlayerJid: senderJid,
        blackPlayerName: senderName.isNotEmpty ? senderName : 'Jugador 2',
      );
      await _store.saveGame(gameToPlay);
    }

    // Movimiento de ajedrez
    if (ChessRefereeEngine.isPotentialMove(cleanText)) {
      final result = _engine.executeMove(
        session: gameToPlay,
        playerJid: senderJid,
        moveText: cleanText,
      );

      if (result.success && result.updatedSession != null) {
        await _store.saveGame(result.updatedSession!);
      }

      return ChessRefereeResponse(
        handled: true,
        replyText: result.message,
        session: result.updatedSession ?? gameToPlay,
        isGameOver: result.isGameOver,
      );
    }

    return ChessRefereeResponse.notHandled;
  }
}
