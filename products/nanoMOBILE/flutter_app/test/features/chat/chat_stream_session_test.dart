import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/chat/application/chat_stream_session.dart';

void main() {
  group('ChatStreamSession', () {
    test('solo la última generación conserva el lease lógico', () {
      final session = ChatStreamSession();
      final first = session.beginGeneration();
      final second = session.beginGeneration();

      expect(session.isGenerationCurrent(first, true), isFalse);
      expect(session.isGenerationCurrent(second, true), isTrue);

      session.dispose();
      expect(session.isGenerationCurrent(second, true), isFalse);
    });

    test('cancelación invalida inmediatamente la generación activa', () {
      final session = ChatStreamSession();
      final generation = session.beginGeneration();

      // La prueba no necesita un motor para verificar la compuerta cooperativa:
      // dispose aplica la misma invalidación síncrona que stop.
      session.dispose();

      expect(session.isGenerationCurrent(generation, true), isFalse);
      expect(session.activeGenerationId, isNull);
    });

    test('sanitiza tokens de control sin fabricar texto vacío', () {
      expect(
        ChatStreamSession.sanitizeGeneratedText('Hola <|im_end|>'),
        'Hola',
      );
      expect(ChatStreamSession.sanitizeGeneratedText(''), isEmpty);
    });
  });
}
