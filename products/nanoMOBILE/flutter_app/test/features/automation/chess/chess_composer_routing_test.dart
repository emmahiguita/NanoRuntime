import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/chess/application/chess_game_store.dart';
import 'package:nanoai/features/automation/chess/application/chess_referee_service.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotificationObject _createTestNotif({
  required String text,
  String sender = 'Carlos',
  String key = 'notif_chess_001',
}) {
  return NotificationObject(
    key: key,
    packageName: 'com.whatsapp',
    title: sender,
    text: text,
    messageText: text,
    messageTimestamp: 1000000,
    sender: sender,
    senderKey: 'pk_$sender',
    senderUri: 'tel:5551234',
    conversationTitle: sender,
    conversationId: 'conv_$sender',
    shortcutId: 'sc_$sender',
    locusId: 'loc_$sender',
    accountHint: '',
    isGroup: false,
    isSummary: false,
    isSelf: false,
    postTime: 1000000,
    canReply: true,
    remoteInputKey: 'quick_reply',
    actionIndex: 0,
    actions: const ['Responder'],
    ongoing: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chess Composer Routing Tests', () {
    late LocalChessGameStore store;
    late ChessRefereeService chessService;
    late RuntimeConversationReplyComposer composer;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = LocalChessGameStore();
      await store.load();
      chessService = ChessRefereeService(store: store);

      composer = RuntimeConversationReplyComposer(
        draftSource: (_) async => null,
        chessService: chessService,
      );
    });

    test('El composer detecta y atiende "♟️ iniciar ajedrez" sin tocar el LLM', () async {
      final notif = _createTestNotif(
        text: '♟️ iniciar ajedrez',
        key: 'notif_start_1',
      );

      final result = await composer.compose(notif);

      expect(result, isNotNull);
      expect(result!.text, contains('¡Partida de Ajedrez Iniciada!'));
      expect(result.text, contains('```'));
      expect(result.understanding.intent, 'chess_game');
      expect(result.decision.disposition, ConversationDisposition.autoSend);

      // Comprobar que la sesión quedó guardada en el store
      final session = store.getGame(result.conversationId);
      expect(session, isNotNull);
      expect(session!.turn, 'w');
    });

    test('El composer atiende un movimiento subsiguiente de ajedrez e2e4', () async {
      // Iniciar primero
      final notif1 = _createTestNotif(
        text: '!ajedrez',
        key: 'notif_start_2',
      );
      await composer.compose(notif1);

      // Ahora Carlos envía e2e4
      final notif2 = _createTestNotif(
        text: 'e2e4',
        key: 'notif_move_2',
      );

      final result2 = await composer.compose(notif2);

      expect(result2, isNotNull);
      expect(result2!.text, contains('Último movimiento: *e2e4*'));
      expect(result2.text, contains('Turno:'));
      expect(result2.understanding.intent, 'chess_game');
      expect(result2.decision.disposition, ConversationDisposition.autoSend);

      final session = store.getGame(result2.conversationId);
      expect(session, isNotNull);
      expect(session!.turn, 'b');
    });
  });
}
