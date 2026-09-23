import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/chess/domain/chess_game_session.dart';
import 'package:nanoai/features/automation/chess/domain/chess_referee_engine.dart';

void main() {
  group('ChessRefereeEngine Tests', () {
    const engine = ChessRefereeEngine();

    test('Detección de comandos de ajedrez', () {
      expect(ChessRefereeEngine.isStartCommand('♟️ iniciar ajedrez'), isTrue);
      expect(ChessRefereeEngine.isStartCommand('!ajedrez'), isTrue);
      expect(ChessRefereeEngine.isStartCommand('hola mundo'), isFalse);

      expect(ChessRefereeEngine.isBoardCommand('!tablero'), isTrue);
      expect(ChessRefereeEngine.isBoardCommand('ver tablero'), isTrue);

      expect(ChessRefereeEngine.isResignCommand('!rendirse'), isTrue);
      expect(ChessRefereeEngine.isResignCommand('me rindo'), isTrue);

      expect(ChessRefereeEngine.isHelpCommand('!ayuda'), isTrue);
    });

    test('Detección de jugadas UCI y SAN', () {
      expect(ChessRefereeEngine.isPotentialMove('e2e4'), isTrue);
      expect(ChessRefereeEngine.isPotentialMove('e4'), isTrue);
      expect(ChessRefereeEngine.isPotentialMove('Nf3'), isTrue);
      expect(ChessRefereeEngine.isPotentialMove('O-O'), isTrue);
      expect(ChessRefereeEngine.isPotentialMove('exd5'), isTrue);
      expect(ChessRefereeEngine.isPotentialMove('hola como estas'), isFalse);
    });

    test('Flujo de partida estándar: Inicio, turnos y movimientos válidos', () {
      final session = engine.startNewGame(
        conversationId: 'chat_123',
        whitePlayerJid: 'user_a',
        blackPlayerJid: 'user_b',
        whitePlayerName: 'Carlos',
        blackPlayerName: 'Ana',
      );

      expect(session.turn, 'w');
      expect(session.status, ChessGameStatus.active);

      // 1. Mueve Blancas (Carlos): e2e4
      final res1 = engine.executeMove(
        session: session,
        playerJid: 'user_a',
        moveText: 'e2e4',
      );

      expect(res1.success, isTrue);
      expect(res1.updatedSession?.turn, 'b');
      expect(res1.message, contains('```')); // Bloque monoespaciado
      expect(res1.message, contains('Turno: *Ana* (Negras)'));

      // 2. Intento fuera de turno: Carlos intenta mover otra vez
      final resOut = engine.executeMove(
        session: res1.updatedSession!,
        playerJid: 'user_a',
        moveText: 'd2d4',
      );
      expect(resOut.success, isFalse);
      expect(resOut.message, contains('No es tu turno'));

      // 3. Mueve Negras (Ana): e7e5
      final res2 = engine.executeMove(
        session: res1.updatedSession!,
        playerJid: 'user_b',
        moveText: 'e7e5',
      );
      expect(res2.success, isTrue);
      expect(res2.updatedSession?.turn, 'w');

      // 4. Movimiento ilegal: Carlos intenta mover un peón a una casilla ocupada
      final resIllegal = engine.executeMove(
        session: res2.updatedSession!,
        playerJid: 'user_a',
        moveText: 'e4e5',
      );
      expect(resIllegal.success, isFalse);
      expect(resIllegal.message, contains('Movimiento ilegal'));
    });

    test('Detección de Jaque Mate (Fool\'s mate)', () {
      var s = engine.startNewGame(
        conversationId: 'chat_mate',
        whitePlayerJid: 'white',
        blackPlayerJid: 'black',
        whitePlayerName: 'Blancas',
        blackPlayerName: 'Negras',
      );

      // 1. f3
      var r = engine.executeMove(session: s, playerJid: 'white', moveText: 'f3');
      expect(r.success, isTrue);
      s = r.updatedSession!;

      // 1... e5
      r = engine.executeMove(session: s, playerJid: 'black', moveText: 'e5');
      expect(r.success, isTrue);
      s = r.updatedSession!;

      // 2. g4
      r = engine.executeMove(session: s, playerJid: 'white', moveText: 'g4');
      expect(r.success, isTrue);
      s = r.updatedSession!;

      // 2... Qh4#
      r = engine.executeMove(session: s, playerJid: 'black', moveText: 'Qh4#');
      expect(r.success, isTrue);
      expect(r.isGameOver, isTrue);
      expect(r.updatedSession?.status, ChessGameStatus.checkmate);
      expect(r.message, contains('JAQUE MATE'));
      expect(r.message, contains('Victoria para *Negras*'));
    });

    test('Rendición de un jugador', () {
      final session = engine.startNewGame(
        conversationId: 'chat_resign',
        whitePlayerJid: 'user_white',
        blackPlayerJid: 'user_black',
        whitePlayerName: 'Jugador 1',
        blackPlayerName: 'Jugador 2',
      );

      final result = engine.resign(
        session: session,
        playerJid: 'user_white',
      );

      expect(result.success, isTrue);
      expect(result.isGameOver, isTrue);
      expect(result.updatedSession?.status, ChessGameStatus.resigned);
      expect(result.message, contains('Jugador 1 se ha rendido'));
      expect(result.message, contains('Victoria para Jugador 2'));
    });
  });
}
