import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/native_conversational_router.dart';
import 'package:nanoai/features/chat/application/chat_control_intent.dart';
import 'package:nanoai/features/chat/application/web_ai_turn_router.dart';

void main() {
  group('órdenes de cancelación', () {
    test('reconoce variantes naturales y tolera cortesía o puntuación', () {
      for (final input in [
        'para',
        'Párate',
        'detente ya',
        'espera, por favor',
        '¡No sigas!',
      ]) {
        expect(ChatControlIntent.isCancellation(input), isTrue, reason: input);
      }
    });

    test('no confunde instrucciones que contienen palabras de control', () {
      for (final input in [
        'para la música',
        'espera una respuesta del servidor',
        'alto rendimiento',
      ]) {
        expect(ChatControlIntent.isCancellation(input), isFalse, reason: input);
      }
    });

    test('responde de forma natural y estable para la misma orden', () {
      final first = ChatControlIntent.cancellationReply('detente ya');
      final second = ChatControlIntent.cancellationReply('detente ya');

      expect(first, equals(second));
      expect(first, isNot(equals('Tarea cancelada.')));
    });
  });

  group('router de Web AI', () {
    test('acepta prefijos y alias de proveedores realmente registrados', () {
      final cases = <String, String>{
        'deepseek: explica Clean Architecture': 'deepseek',
        'pregunta a Chat GPT cómo estás': 'chatgpt',
        'usa Le Chat - resume esto': 'mistral',
        'OpenAI, prueba': 'chatgpt',
      };

      for (final entry in cases.entries) {
        final request = WebAiTurnRouter.parseRequest(entry.key);
        expect(request, isNotNull, reason: entry.key);
        expect(request!.providerId, entry.value, reason: entry.key);
        expect(request.prompt, isNotEmpty, reason: entry.key);
      }
    });

    test(
      'no acepta nombres concatenados ni proveedores sin implementación',
      () {
        expect(WebAiTurnRouter.parseRequest('chatgptfoo'), isNull);
        expect(WebAiTurnRouter.parseRequest('kimi: explica esto'), isNull);
        expect(WebAiTurnRouter.parseRequest('llama: explica esto'), isNull);
      },
    );
  });

  group('conversación social sin modelo', () {
    test('resuelve saludo y agradecimiento sin enviar al LLM', () {
      const router = NativeConversationalRouter();

      expect(router.tryResolve('hola', hasModel: false), isNotNull);
      expect(router.tryResolve('gracias', hasModel: false), isNotNull);
    });
  });
}
