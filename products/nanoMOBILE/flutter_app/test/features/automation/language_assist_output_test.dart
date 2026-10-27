import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/language_assist.dart';

void main() {
  group('LanguageAssistService.safeCleanOutput', () {
    test('removes leaked protocol labels from a conversational reply', () {
      expect(
        LanguageAssistService.safeCleanOutput('Respuesta: Claro, te confirmo.'),
        'Claro, te confirmo.',
      );
      expect(
        LanguageAssistService.safeCleanOutput('assistant: Ya lo reviso.'),
        'Ya lo reviso.',
      );
    });

    test('collapses excessive and mixed terminal punctuation', () {
      expect(
        LanguageAssistService.safeCleanOutput('¿En serio?!?!!  Sí,,, claro!!!'),
        '¿En serio? Sí, claro!',
      );
    });

    test('preserves natural ellipsis and inverted Spanish marks', () {
      expect(
        LanguageAssistService.safeCleanOutput('¿Me cuentas? Bueno... te leo.'),
        '¿Me cuentas? Bueno... te leo.',
      );
    });
  });
}
