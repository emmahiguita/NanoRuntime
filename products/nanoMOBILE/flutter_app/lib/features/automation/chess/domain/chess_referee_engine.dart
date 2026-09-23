/// CHESS-REFEREE-ENGINE — Motor formal determinista y árbitro de ajedrez para Nano AI.
///
/// **QUÉ HACE:**
/// Valida jugadas de ajedrez según las reglas oficiales FIDE, controla turnos,
/// detecta estados finales (jaque, mate, ahogado, tablas) y renderiza el tablero
/// en formato monoespaciado Unicode para WhatsApp.
///
/// **CÓMO FUNCIONA:**
/// Utiliza `package:chess/chess.dart` como motor subyacente. Parsea comandos de usuario,
/// convierte coordenadas UCI o notación algebraica SAN y actualiza la sesión.
///
/// **POR QUÉ:**
/// Elimina cualquier posibilidad de alucinación por parte del LLM. El árbitro es 100%
/// determinista, tiene latencia inferior a 5 ms y consume 0 tokens.
library;

import 'package:chess/chess.dart' as chess_lib;
import 'chess_game_session.dart';

final class MoveExecutionResult {
  final bool success;
  final String message;
  final ChessGameSession? updatedSession;
  final bool isGameOver;

  const MoveExecutionResult({
    required this.success,
    required this.message,
    this.updatedSession,
    this.isGameOver = false,
  });
}

final class ChessRefereeEngine {
  const ChessRefereeEngine();

  /// Detecta si el texto es una solicitud para iniciar una partida de ajedrez.
  static bool isStartCommand(String text) {
    final lower = text.trim().toLowerCase();
    return lower.contains('iniciar ajedrez') ||
        lower.contains('jugar ajedrez') ||
        lower.contains('!ajedrez') ||
        lower.contains('/chess') ||
        lower.contains('♟️ ajedrez') ||
        lower == '♟️' ||
        lower == 'ajedrez';
  }

  /// Detecta si el texto solicita ver el tablero actual.
  static bool isBoardCommand(String text) {
    final lower = text.trim().toLowerCase();
    return lower == '!tablero' ||
        lower == 'tablero' ||
        lower == 'ver tablero' ||
        lower == 'mostrar tablero';
  }

  /// Detecta si el jugador desea rendirse.
  static bool isResignCommand(String text) {
    final lower = text.trim().toLowerCase();
    return lower == '!rendirse' ||
        lower == 'me rindo' ||
        lower == 'rendirse' ||
        lower == 'abandonar';
  }

  /// Detecta si el jugador ofrece o pide tablas.
  static bool isDrawCommand(String text) {
    final lower = text.trim().toLowerCase();
    return lower == '!tablas' || lower == 'tablas' || lower == 'empate';
  }

  /// Detecta si el texto es un comando de ayuda.
  static bool isHelpCommand(String text) {
    final lower = text.trim().toLowerCase();
    return lower == '!ayuda' ||
        lower == 'ayuda ajedrez' ||
        lower == 'reglas ajedrez';
  }

  /// Detecta si el texto tiene formato de jugada de ajedrez (UCI o SAN).
  static bool isPotentialMove(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 8) return false;

    // Coordenadas UCI: e2e4, g1f3, e7e8q
    final uciRegex = RegExp(r'^[a-h][1-8][a-h][1-8][qrbnQRBN]?$');
    if (uciRegex.hasMatch(trimmed)) return true;

    // Enroques
    if (trimmed == 'O-O' || trimmed == 'O-O-O' || trimmed == '0-0' || trimmed == '0-0-0') {
      return true;
    }

    // Notación SAN: e4, Nf3, Bxe7, exd5, Qh5#, a8=Q, etc.
    final sanRegex = RegExp(
      r'^[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](=[QRBN])?[\+#]?$',
    );
    return sanRegex.hasMatch(trimmed);
  }

  /// Inicia una nueva partida con los dos jugadores indicados.
  ChessGameSession startNewGame({
    required String conversationId,
    required String whitePlayerJid,
    required String blackPlayerJid,
    required String whitePlayerName,
    required String blackPlayerName,
    bool isVsAi = false,
  }) {
    final chess = chess_lib.Chess();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return ChessGameSession(
      id: '${conversationId}_$nowMs',
      conversationId: conversationId,
      whitePlayerJid: whitePlayerJid,
      blackPlayerJid: blackPlayerJid,
      whitePlayerName: whitePlayerName,
      blackPlayerName: blackPlayerName,
      fen: chess.fen,
      pgn: '',
      turn: 'w',
      status: ChessGameStatus.active,
      lastMoveAtMs: nowMs,
      startedAtMs: nowMs,
      isVsAi: isVsAi,
    );
  }

  /// Ejecuta un movimiento en la sesión activa.
  MoveExecutionResult executeMove({
    required ChessGameSession session,
    required String playerJid,
    required String moveText,
  }) {
    // 1. Validar que la partida esté activa
    if (session.status.isGameOver) {
      return MoveExecutionResult(
        success: false,
        message: '🏁 La partida ya ha finalizado (${session.status.name}). Envía "!ajedrez" para iniciar una nueva.',
        isGameOver: true,
      );
    }

    // 2. Validar que sea el turno del jugador
    if (!session.isTurn(playerJid)) {
      final currentName = session.currentTurnPlayerName();
      return MoveExecutionResult(
        success: false,
        message: '⏳ No es tu turno. Le toca a $currentName (${session.turn == 'w' ? 'Blancas' : 'Negras'}).',
      );
    }

    // 3. Cargar estado en chess_lib
    final chess = chess_lib.Chess.fromFEN(session.fen);
    final cleanMove = moveText.trim();

    // Normalizar formato de enroque si usaron ceros
    final normalizedMove = cleanMove == '0-0'
        ? 'O-O'
        : cleanMove == '0-0-0'
            ? 'O-O-O'
            : cleanMove;

    bool moveApplied = false;

    // Intentar mover como UCI (e2e4, etc.)
    final uciRegex = RegExp(r'^([a-h][1-8])([a-h][1-8])([qrbnQRBN])?$');
    final match = uciRegex.firstMatch(normalizedMove);
    if (match != null) {
      final from = match.group(1)!;
      final to = match.group(2)!;
      final promotion = match.group(3)?.toLowerCase();

      final moveOptions = <String, dynamic>{'from': from, 'to': to};
      if (promotion != null) {
        moveOptions['promotion'] = promotion;
      }
      moveApplied = chess.move(moveOptions);
    } else {
      // Intentar mover como SAN (e4, Nf3, etc.)
      moveApplied = chess.move(normalizedMove);
    }

    if (!moveApplied) {
      final legalMoves = chess.moves();
      final sample = legalMoves.take(6).join(', ');
      return MoveExecutionResult(
        success: false,
        message: '❌ Movimiento ilegal: "$cleanMove".\n💡 Jugadas legales posibles: $sample...',
      );
    }

    // 4. Evaluar nuevo estado de la partida
    ChessGameStatus newStatus = ChessGameStatus.active;
    String? winner;

    if (chess.in_checkmate) {
      newStatus = ChessGameStatus.checkmate;
      winner = session.turn; // El que acaba de mover ganó
    } else if (chess.in_stalemate ||
        chess.in_threefold_repetition ||
        chess.insufficient_material ||
        chess.in_draw) {
      newStatus = ChessGameStatus.draw;
      winner = 'draw';
    } else if (chess.in_check) {
      newStatus = ChessGameStatus.check;
    }

    final nextTurn = chess.turn == chess_lib.Color.WHITE ? 'w' : 'b';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final updated = session.copyWith(
      fen: chess.fen,
      pgn: chess.pgn(),
      turn: nextTurn,
      status: newStatus,
      winner: winner,
      lastMove: cleanMove,
      lastMoveAtMs: nowMs,
    );

    // 5. Renderizar respuesta formateada
    final boardMsg = formatBoardMessage(
      session: updated,
      highlightMove: cleanMove,
    );

    return MoveExecutionResult(
      success: true,
      message: boardMsg,
      updatedSession: updated,
      isGameOver: newStatus.isGameOver,
    );
  }

  /// Rinde al jugador indicado.
  MoveExecutionResult resign({
    required ChessGameSession session,
    required String playerJid,
  }) {
    if (session.status.isGameOver) {
      return const MoveExecutionResult(
        success: false,
        message: 'La partida ya había concluido.',
        isGameOver: true,
      );
    }

    final isWhite = playerJid == session.whitePlayerJid;
    final winner = isWhite ? 'b' : 'w';
    final resigningName = isWhite ? session.whitePlayerName : session.blackPlayerName;
    final winnerName = isWhite ? session.blackPlayerName : session.whitePlayerName;

    final updated = session.copyWith(
      status: ChessGameStatus.resigned,
      winner: winner,
      lastMoveAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    final msg = '🏳️ *$resigningName se ha rendido.*\n🏆 *¡Victoria para $winnerName!*\n\nEnvía "!ajedrez" para comenzar otra partida.';
    return MoveExecutionResult(
      success: true,
      message: msg,
      updatedSession: updated,
      isGameOver: true,
    );
  }

  /// Renderiza el mensaje completo del tablero para WhatsApp en bloque monoespaciado.
  static String formatBoardMessage({
    required ChessGameSession session,
    String? highlightMove,
  }) {
    final chess = chess_lib.Chess.fromFEN(session.fen);
    final boardAscii = renderUnicodeBoard(chess);

    final turnName = session.currentTurnPlayerName();
    final turnColorStr = session.turn == 'w' ? 'Blancas' : 'Negras';

    final sb = StringBuffer();
    sb.writeln('♟️ *Nano Chess Referee*');
    sb.writeln('⚪ ${session.whitePlayerName} vs ⚫ ${session.blackPlayerName}');

    if (highlightMove != null) {
      sb.writeln('Último movimiento: *$highlightMove*');
    }

    if (session.status == ChessGameStatus.checkmate) {
      final winnerName = session.winner == 'w'
          ? session.whitePlayerName
          : session.blackPlayerName;
      sb.writeln('🚨 *¡JAQUE MATE!* 🏆 Victoria para *$winnerName*.');
    } else if (session.status == ChessGameStatus.check) {
      sb.writeln('⚠️ *¡JAQUE!* Turno de *$turnName* ($turnColorStr).');
    } else if (session.status == ChessGameStatus.draw) {
      sb.writeln('🤝 *Partida en Tablas (Empate).*');
    } else if (session.status == ChessGameStatus.resigned) {
      sb.writeln('🏳️ *Partida finalizada por rendición.*');
    } else {
      sb.writeln('Turno: *$turnName* ($turnColorStr)');
    }

    sb.writeln();
    // Bloque monoespaciado en WhatsApp con triple comilla invertida
    sb.writeln('```');
    sb.writeln(boardAscii);
    sb.writeln('```');

    if (!session.status.isGameOver) {
      sb.writeln('Envía tu jugada (ej. "e4" o "e2e4"). Comandos: "!tablero", "!rendirse", "!ayuda".');
    } else {
      sb.writeln('Envía "!ajedrez" para iniciar una nueva partida.');
    }

    return sb.toString().trim();
  }

  /// Dibuja el tablero 8x8 con piezas Unicode elegantes y coordenadas legibles.
  static String renderUnicodeBoard(chess_lib.Chess chess) {
    // Mapeo Unicode: Blancas / Negras
    const pieceMap = {
      'p': '♟',
      'r': '♜',
      'n': '♞',
      'b': '♝',
      'q': '♛',
      'k': '♚',
      'P': '♙',
      'R': '♖',
      'N': '♘',
      'B': '♗',
      'Q': '♕',
      'K': '♔',
    };

    final lines = <String>[];
    lines.add('   a  b  c  d  e  f  g  h');

    for (int rank = 8; rank >= 1; rank--) {
      final rowPieces = <String>[];
      for (int file = 0; file < 8; file++) {
        final square = '${String.fromCharCode('a'.codeUnitAt(0) + file)}$rank';
        final piece = chess.get(square);
        if (piece == null) {
          rowPieces.add('·');
        } else {
          final symbol = piece.type.name.toLowerCase();
          final key = piece.color == chess_lib.Color.WHITE ? symbol.toUpperCase() : symbol;
          rowPieces.add(pieceMap[key] ?? '·');
        }
      }
      lines.add('$rank  ${rowPieces.join('  ')}  $rank');
    }

    lines.add('   a  b  c  d  e  f  g  h');
    return lines.join('\n');
  }

  /// Texto de ayuda para los jugadores.
  static String helpText() {
    return '''
♟️ *Nano Chess — Guía de Comandos*

1. *Movimientos*: Envía jugadas en notación estándar:
   • Coordenadas: "e2e4", "g1f3", "e7e8q"
   • Notación abreviada: "e4", "Nf3", "Bxf7+", "O-O" (enroque corto), "O-O-O" (enroque largo)

2. *Comandos*:
   • "!tablero" : Ver el estado del tablero actual
   • "!rendirse" : Abandonar la partida actual
   • "!tablas" : Proponer empate
   • "!ajedrez" : Iniciar un nuevo juego

Todo se valida automáticamente según las reglas FIDE oficiales.
'''.trim();
  }
}
