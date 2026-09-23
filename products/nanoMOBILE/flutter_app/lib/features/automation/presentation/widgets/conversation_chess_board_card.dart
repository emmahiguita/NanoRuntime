/// CONVERSATION-CHESS-BOARD-CARD — Visor y controlador interactivo de ajedrez en Nano AI.
///
/// **QUÉ HACE:**
/// Renderiza un tablero de ajedrez visual de 8x8 con cuadrícula adaptada al diseño
/// oscuro de Nano AI, selector de casillas, visualización de piezas y control de jugadas.
///
/// **CÓMO FUNCIONA:**
/// Se suscribe a la sesión de ajedrez activa de la conversación, parsea la posición FEN
/// y permite al dueño del móvil jugar directamente tocando las casillas o revisar la partida.
///
/// **POR QUÉ:**
/// Permite al usuario experimentar la partida directamente dentro del Centro de Atención
/// de Nano AI sin depender únicamente de la pantalla de WhatsApp.
library;

import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chess/application/chess_game_store.dart';
import '../../chess/domain/chess_game_session.dart';
import '../../chess/domain/chess_referee_engine.dart';

class ConversationChessBoardCard extends ConsumerStatefulWidget {
  final String conversationId;
  final VoidCallback? onMoveExecuted;

  const ConversationChessBoardCard({
    super.key,
    required this.conversationId,
    this.onMoveExecuted,
  });

  @override
  ConsumerState<ConversationChessBoardCard> createState() =>
      _ConversationChessBoardCardState();
}

class _ConversationChessBoardCardState
    extends ConsumerState<ConversationChessBoardCard> {
  String? _selectedSquare;
  bool _isExpanded = true;

  static const Map<String, String> _pieceSymbols = {
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

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(chessGameStoreProvider);
    final session = store.getGame(widget.conversationId);

    if (session == null || session.status.isGameOver) {
      return const SizedBox.shrink();
    }

    final chess = chess_lib.Chess.fromFEN(session.fen);
    final isWhiteTurn = session.turn == 'w';
    final turnName = session.currentTurnPlayerName();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00FF88).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header de la partida
          ListTile(
            dense: true,
            leading: const Text('♟️', style: TextStyle(fontSize: 22)),
            title: Text(
              '${session.whitePlayerName} vs ${session.blackPlayerName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              session.status == ChessGameStatus.check
                  ? '⚠️ ¡JAQUE! Turno de $turnName'
                  : 'Turno: $turnName (${isWhiteTurn ? "Blancas" : "Negras"})',
              style: TextStyle(
                color: session.status == ChessGameStatus.check
                    ? const Color(0xFFFF5555)
                    : const Color(0xFF00FF88),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(10),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _buildBoard(chess, session),
              ),
            ),
            _buildActionsBar(session),
          ],
        ],
      ),
    );
  }

  Widget _buildBoard(chess_lib.Chess chess, ChessGameSession session) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            for (int rank = 8; rank >= 1; rank--)
              Expanded(
                child: Row(
                  children: [
                    for (int file = 0; file < 8; file++)
                      Expanded(
                        child: _buildSquare(
                          file: file,
                          rank: rank,
                          chess: chess,
                          session: session,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquare({
    required int file,
    required int rank,
    required chess_lib.Chess chess,
    required ChessGameSession session,
  }) {
    final square = '${String.fromCharCode('a'.codeUnitAt(0) + file)}$rank';
    final isDarkSquare = (file + rank) % 2 == 0;
    final isSelected = _selectedSquare == square;
    final piece = chess.get(square);

    Color bg = isDarkSquare
        ? const Color(0xFF334155)
        : const Color(0xFF475569);

    if (isSelected) {
      bg = const Color(0xFF00FF88).withValues(alpha: 0.50);
    }

    String? symbol;
    if (piece != null) {
      final key = piece.color == chess_lib.Color.WHITE
          ? piece.type.name.toUpperCase()
          : piece.type.name.toLowerCase();
      symbol = _pieceSymbols[key];
    }

    return GestureDetector(
      onTap: () => _handleSquareTap(square, piece, session),
      child: Container(
        color: bg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (symbol != null)
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 22,
                  color: piece?.color == chess_lib.Color.WHITE
                      ? Colors.white
                      : const Color(0xFF0F172A),
                  shadows: const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            if (file == 0)
              Positioned(
                top: 1,
                left: 2,
                child: Text(
                  '$rank',
                  style: const TextStyle(fontSize: 8, color: Colors.white38),
                ),
              ),
            if (rank == 1)
              Positioned(
                bottom: 1,
                right: 2,
                child: Text(
                  String.fromCharCode('a'.codeUnitAt(0) + file),
                  style: const TextStyle(fontSize: 8, color: Colors.white38),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleSquareTap(
    String square,
    chess_lib.Piece? piece,
    ChessGameSession session,
  ) {
    if (_selectedSquare == null) {
      if (piece != null) {
        setState(() => _selectedSquare = square);
      }
      return;
    }

    // Si ya había una casilla seleccionada, intentamos mover
    final from = _selectedSquare!;
    final to = square;

    if (from == to) {
      setState(() => _selectedSquare = null);
      return;
    }

    final moveUci = '$from$to';
    const engine = ChessRefereeEngine();
    final result = engine.executeMove(
      session: session,
      playerJid: session.currentTurnPlayerJid(),
      moveText: moveUci,
    );

    if (result.success && result.updatedSession != null) {
      ref.read(chessGameStoreProvider).saveGame(result.updatedSession!);
      setState(() => _selectedSquare = null);
      widget.onMoveExecuted?.call();
    } else {
      // Si tocó otra de sus propias piezas, cambiamos la selección
      if (piece != null) {
        setState(() => _selectedSquare = square);
      } else {
        setState(() => _selectedSquare = null);
      }
    }
  }

  Widget _buildActionsBar(ChessGameSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            session.lastMove != null
                ? 'Último: ${session.lastMove}'
                : 'Partida recién iniciada',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B6B),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.flag_outlined, size: 14),
            label: const Text('Rendirse', style: TextStyle(fontSize: 11)),
            onPressed: () async {
              const engine = ChessRefereeEngine();
              final res = engine.resign(
                session: session,
                playerJid: session.currentTurnPlayerJid(),
              );
              if (res.updatedSession != null) {
                await ref
                    .read(chessGameStoreProvider)
                    .saveGame(res.updatedSession!);
                widget.onMoveExecuted?.call();
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
