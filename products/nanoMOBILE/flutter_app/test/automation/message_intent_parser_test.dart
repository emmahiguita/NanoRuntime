import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/message_intent_parser.dart';

void main() {
  const parser = MessageIntentParser();

  group('MessageIntentParser · separación recipient/mensaje', () {
    test('"responde a Juan que llego a las 8" → Juan + llego a las 8', () {
      final i = parser.parse('responde a Juan que llego a las 8');
      expect(i.recipient, 'Juan');
      expect(i.message, 'llego a las 8');
    });

    test('"responde a Juan: llego a las 8" → Juan + llego a las 8', () {
      final i = parser.parse('responde a Juan: llego a las 8');
      expect(i.recipient, 'Juan');
      expect(i.message, 'llego a las 8');
    });

    test('"contesta a María que ya voy" → María + ya voy', () {
      final i = parser.parse('contesta a María que ya voy');
      expect(i.recipient, 'María');
      expect(i.message, 'ya voy');
    });

    test(
      '"responde el último mensaje de Juan que llego en 20 minutos"',
      () {
        final i = parser.parse(
          'responde el último mensaje de Juan que llego en 20 minutos',
        );
        expect(i.recipient, 'Juan');
        expect(i.message, 'llego en 20 minutos');
      },
    );

    test('"reply to Juan that I am coming" → Juan + I am coming', () {
      final i = parser.parse('reply to Juan that I am coming');
      expect(i.recipient, 'Juan');
      expect(i.message, 'I am coming');
    });

    test('sin separador de mensaje → recipient, sin message', () {
      final i = parser.parse('responde a Juan');
      expect(i.recipient, 'Juan');
      expect(i.message, isEmpty);
      expect(i.hasMessage, isFalse);
    });

    test('sin verbo → todo vacío', () {
      final i = parser.parse('abre Chrome');
      expect(i.recipient, isEmpty);
      expect(i.message, isEmpty);
    });

    test('puntuación de borde se limpia del mensaje', () {
      final i = parser.parse('responde a Juan que llego!');
      expect(i.message, 'llego');
    });
  });

  group('MessageIntentParser · verbos de mensajería (T2.8)', () {
    test('"escríbele a Juan: hola" → Juan + hola', () {
      final i = parser.parse('escríbele a Juan: hola');
      expect(i.recipient, 'Juan');
      expect(i.message, 'hola');
    });

    test('"escríbele a Juan que llego en 20 minutos" → Juan + mensaje', () {
      final i = parser.parse('escríbele a Juan que llego en 20 minutos');
      expect(i.recipient, 'Juan');
      expect(i.message, 'llego en 20 minutos');
    });

    test('"envía un mensaje a María: ya voy" → María + ya voy', () {
      final i = parser.parse('envía un mensaje a María: ya voy');
      expect(i.recipient, 'María');
      expect(i.message, 'ya voy');
    });

    test('"message to Pedro: on my way" → Pedro + on my way', () {
      final i = parser.parse('message to Pedro: on my way');
      expect(i.recipient, 'Pedro');
      expect(i.message, 'on my way');
    });
  });
}
