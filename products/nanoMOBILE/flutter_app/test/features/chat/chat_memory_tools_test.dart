import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/features/chat/domain/chat_social_reply_resolver.dart';
import 'package:nanoai/features/chat/domain/chat_memory_tools.dart';

void main() {
  const memory = ChatMemoryTools();
  const socialReplies = ChatSocialReplyResolver();

  ChatMessage message(
    MessageSender sender,
    String text, {
    DateTime? timestamp,
  }) => ChatMessage(
    id: '${sender.name}-${timestamp?.millisecondsSinceEpoch ?? text.hashCode}',
    sender: sender,
    text: text,
    timestamp: timestamp ?? DateTime(2026, 1, 1),
    status: MessageStatus.sent,
  );

  group('memoria propia del chat', () {
    test(
      'recupera un mensaje real aunque ya no esté en la ventana reciente',
      () {
        final history = [
          message(
            MessageSender.user,
            'Recuerda que me gusta el café de Colombia.',
          ),
          ...List.generate(
            16,
            (index) => message(
              index.isEven ? MessageSender.user : MessageSender.ai,
              'Hablamos de otro tema número $index.',
              timestamp: DateTime(2026, 1, 1, 0, index),
            ),
          ),
        ];

        final reply = memory.resolveCommand(
          input: '¿Qué te dije sobre el café?',
          history: history,
        );

        expect(reply, isNotNull);
        expect(reply!.text, contains('me gusta el café de Colombia'));
        expect(reply.suggestions, hasLength(3));
      },
    );

    test('recuerda explícitamente dentro del historial de Chat', () {
      final reply = memory.resolveCommand(
        input: 'Recuerda que prefiero respuestas breves.',
        history: const [],
      );

      expect(reply, isNotNull);
      expect(reply!.text, contains('prefiero respuestas breves'));
      expect(reply.text, contains('este chat'));
    });

    test('explica cómo usar la memoria del chat', () {
      final reply = memory.resolveCommand(
        input: '¿Cómo funciona tu memoria?',
        history: const [],
      );

      expect(reply, isNotNull);
      expect(reply!.text, contains('mensajes guardados de esta conversación'));
      expect(reply.text, contains('¿Qué te dije sobre …?'));
    });

    test('inyecta solo recuerdos relacionados y usa el historial completo', () {
      final history = [
        message(MessageSender.user, 'Me gusta el café de Colombia.'),
        ...List.generate(
          14,
          (index) => message(
            MessageSender.user,
            'Conversación irrelevante número $index.',
          ),
        ),
      ];

      final context = memory.contextFor(history, '¿Qué café me gusta?');

      expect(context, contains('Me gusta el café de Colombia'));
      expect(context, isNot(contains('Conversación irrelevante')));
    });

    test(
      'entiende “bien” como respuesta solo si el chat preguntó cómo está',
      () {
        final greeting = [
          message(MessageSender.user, 'Hola'),
          message(MessageSender.ai, '¡Hola! ¿Cómo estás?'),
        ];

        final reply = socialReplies.resolve('bien', greeting);
        expect(reply, isNotNull);
        expect(reply!.text, contains('Me alegra'));
        expect(reply.suggestions, contains('Tengo una pregunta'));
        expect(socialReplies.resolve('Tengo una pregunta', greeting), isNull);
        expect(
          socialReplies.resolve('Estoy bien, ayúdame con algo', greeting),
          isNull,
        );
        expect(
          socialReplies.resolve('bien', [
            message(MessageSender.ai, 'Puedo ayudarte con una pregunta.'),
          ]),
          isNull,
        );
        expect(
          socialReplies.resolve('bien', [
            message(MessageSender.ai, '¡Hola! ¿Cómo estás?'),
            message(MessageSender.user, '¿Puedes ayudarme con una duda?'),
          ]),
          isNull,
        );
      },
    );
  });
}
