/// CHESS-GAME-SESSION — Entidad de dominio para una partida de ajedrez en Nano AI.
///
/// **QUÉ HACE:**
/// Representa el estado inmutable de una partida de ajedrez en un chat o grupo,
/// incluyendo jugadores, FEN, PGN, turno actual, estado de jaque/mate y metadatos.
///
/// **CÓMO FUNCIONA:**
/// Almacena las identidades JID de blancas y negras, el estado FEN canónico de la
/// posición FIDE y serializa a JSON para persistencia local inmediata en SQLite/Prefs.
///
/// **POR QUÉ:**
/// Garantiza determinismo estricto (< 180 líneas) aislando la representación del
/// estado de la lógica del motor o del canal de mensajería.
library;

enum ChessGameStatus {
  active,
  check,
  checkmate,
  stalemate,
  draw,
  resigned;

  bool get isGameOver =>
      this == ChessGameStatus.checkmate ||
      this == ChessGameStatus.stalemate ||
      this == ChessGameStatus.draw ||
      this == ChessGameStatus.resigned;

  static ChessGameStatus fromString(String? value) {
    return ChessGameStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChessGameStatus.active,
    );
  }
}

final class ChessGameSession {
  final String id;
  final String conversationId;
  final String whitePlayerJid;
  final String blackPlayerJid;
  final String whitePlayerName;
  final String blackPlayerName;
  final String fen;
  final String pgn;
  final String turn; // 'w' o 'b'
  final ChessGameStatus status;
  final String? winner; // 'w', 'b', 'draw' o null
  final String? lastMove;
  final int lastMoveAtMs;
  final int startedAtMs;
  final bool isVsAi;

  const ChessGameSession({
    required this.id,
    required this.conversationId,
    required this.whitePlayerJid,
    required this.blackPlayerJid,
    required this.whitePlayerName,
    required this.blackPlayerName,
    required this.fen,
    required this.pgn,
    required this.turn,
    this.status = ChessGameStatus.active,
    this.winner,
    this.lastMove,
    required this.lastMoveAtMs,
    required this.startedAtMs,
    this.isVsAi = false,
  });

  bool isTurn(String playerJid) {
    if (turn == 'w' && playerJid == whitePlayerJid) return true;
    if (turn == 'b' && playerJid == blackPlayerJid) return true;
    return false;
  }

  String currentTurnPlayerName() {
    return turn == 'w' ? whitePlayerName : blackPlayerName;
  }

  String currentTurnPlayerJid() {
    return turn == 'w' ? whitePlayerJid : blackPlayerJid;
  }

  ChessGameSession copyWith({
    String? id,
    String? conversationId,
    String? whitePlayerJid,
    String? blackPlayerJid,
    String? whitePlayerName,
    String? blackPlayerName,
    String? fen,
    String? pgn,
    String? turn,
    ChessGameStatus? status,
    String? winner,
    String? lastMove,
    int? lastMoveAtMs,
    int? startedAtMs,
    bool? isVsAi,
  }) {
    return ChessGameSession(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      whitePlayerJid: whitePlayerJid ?? this.whitePlayerJid,
      blackPlayerJid: blackPlayerJid ?? this.blackPlayerJid,
      whitePlayerName: whitePlayerName ?? this.whitePlayerName,
      blackPlayerName: blackPlayerName ?? this.blackPlayerName,
      fen: fen ?? this.fen,
      pgn: pgn ?? this.pgn,
      turn: turn ?? this.turn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      lastMove: lastMove ?? this.lastMove,
      lastMoveAtMs: lastMoveAtMs ?? this.lastMoveAtMs,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      isVsAi: isVsAi ?? this.isVsAi,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'whitePlayerJid': whitePlayerJid,
    'blackPlayerJid': blackPlayerJid,
    'whitePlayerName': whitePlayerName,
    'blackPlayerName': blackPlayerName,
    'fen': fen,
    'pgn': pgn,
    'turn': turn,
    'status': status.name,
    'winner': winner,
    'lastMove': lastMove,
    'lastMoveAtMs': lastMoveAtMs,
    'startedAtMs': startedAtMs,
    'isVsAi': isVsAi,
  };

  factory ChessGameSession.fromJson(Map<String, dynamic> json) {
    return ChessGameSession(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      whitePlayerJid: json['whitePlayerJid'] as String? ?? '',
      blackPlayerJid: json['blackPlayerJid'] as String? ?? '',
      whitePlayerName: json['whitePlayerName'] as String? ?? 'Blancas',
      blackPlayerName: json['blackPlayerName'] as String? ?? 'Negras',
      fen: json['fen'] as String? ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      pgn: json['pgn'] as String? ?? '',
      turn: json['turn'] as String? ?? 'w',
      status: ChessGameStatus.fromString(json['status'] as String?),
      winner: json['winner'] as String?,
      lastMove: json['lastMove'] as String?,
      lastMoveAtMs: (json['lastMoveAtMs'] as num?)?.toInt() ?? 0,
      startedAtMs: (json['startedAtMs'] as num?)?.toInt() ?? 0,
      isVsAi: json['isVsAi'] as bool? ?? false,
    );
  }
}
