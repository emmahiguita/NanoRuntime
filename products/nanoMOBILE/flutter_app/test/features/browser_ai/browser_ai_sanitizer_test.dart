import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_sanitizer.dart';

void main() {
  group('BrowserAiSanitizer — Redacción de Datos Privados', () {
    const sanitizer = BrowserAiSanitizer();

    test('Redacta correos electrónicos de cualquier dominio', () {
      const input = 'Contactar a usuario@ejemplo.com o admin.test@empresa.co para soporte.';
      final result = sanitizer.sanitize(input);

      expect(result, isNot(contains('usuario@ejemplo.com')));
      expect(result, isNot(contains('admin.test@empresa.co')));
      expect(result, contains('[EMAIL_REDACTADO]'));
    });

    test('Redacta números telefónicos locales e internacionales', () {
      const input = 'Llamar al +57 300 123 4567 o al (601) 555-0199 urgente.';
      final result = sanitizer.sanitize(input);

      expect(result, isNot(contains('+57 300 123 4567')));
      expect(result, isNot(contains('555-0199')));
      expect(result, contains('[TELEFONO_REDACTADO]'));
    });

    test('Conserva números ordinarios como años o cantidades', () {
      const input = 'En el año 2026 hubo 150 participantes en el evento.';
      final result = sanitizer.sanitize(input);

      expect(result, equals('En el año 2026 hubo 150 participantes en el evento.'));
    });

    test('Redacta números de tarjetas de crédito o débito', () {
      const input = 'Pagar con la tarjeta 4532-1234-5678-9010 en la pasarela.';
      final result = sanitizer.sanitize(input);

      expect(result, isNot(contains('4532-1234-5678-9010')));
      expect(result, contains('[NUMERO_PAGO_REDACTADO]'));
    });

    test('Redacta tokens de OpenAI, GitHub y cabeceras Bearer', () {
      const input = 'Mi clave es sk-1234567890abcdef1234567890 y token Bearer abcdef1234567890abcdef1234567890.';
      final result = sanitizer.sanitize(input);

      expect(result, isNot(contains('sk-1234567890')));
      expect(result, contains('[CREDENCIAL_REDACTADA]'));
    });

    test('Maneja entradas vacías o compuestas sólo de espacios', () {
      expect(sanitizer.sanitize(''), equals(''));
      expect(sanitizer.sanitize('   '), equals('   '));
    });
  });
}
