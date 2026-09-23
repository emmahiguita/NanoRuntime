import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/chess/application/chess_game_store.dart';
import 'package:nanoai/features/automation/chess/application/chess_referee_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChessGameStore & ChessRefereeService Tests', () {
    late LocalChessGameStore store;
    late ChessRefereeService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = LocalChessGameStore();
      await store.load();
      service = ChessRefereeService(store: store);
    });

    test('Flujo completo de servicio: inicio, jugadas, consulta de tablero y persistencia', () async {
      const convId = 'chat_e2e_1';

      // 1. Mensaje ordinario no debe ser manejado
      final ordinary = service.shouldHandleMessage(
        conversationId: convId,
        text: 'Hola, ¿cómo estás hoy?',
      );
      expect(ordinary, isFalse);

      // 2. Iniciar partida
      final startRes = await service.processMessage(
        conversationId: convId,
        senderJid: 'user_a',
        senderName: 'Carlos',
        text: '♟️ iniciar ajedrez',
        ownerName: 'Emmanuel',
      );

      expect(startRes.handled, isTrue);
      expect(startRes.replyText, contains('¡Partida de Ajedrez Iniciada!'));
      expect(startRes.session, isNotNull);
      expect(store.getGame(convId), isNotNull);

      // 3. Ahora las jugadas potenciales sí son reconocidas
      final handlesMove = service.shouldHandleMessage(
        conversationId: convId,
        text: 'e2e4',
      );
      expect(handlesMove, isTrue);

      // 4. Carlos mueve e2e4
      final move1 = await service.processMessage(
        conversationId: convId,
        senderJid: 'user_a',
        senderName: 'Carlos',
        text: 'e2e4',
      );

      expect(move1.handled, isTrue);
      expect(move1.session?.turn, 'b');

      // 5. Ver tablero
      final boardRes = await service.processMessage(
        conversationId: convId,
        senderJid: 'user_b',
        senderName: 'Emmanuel',
        text: '!tablero',
      );

      expect(boardRes.handled, isTrue);
      expect(boardRes.replyText, contains('Nano Chess Referee'));

      // 6. Proponer tablas
      final drawRes = await service.processMessage(
        conversationId: convId,
        senderJid: 'user_b',
        senderName: 'Emmanuel',
        text: '!tablas',
      );

      expect(drawRes.handled, isTrue);
      expect(drawRes.isGameOver, isTrue);
      expect(drawRes.replyText, contains('Tablas acordadas'));
    });
  });
}
