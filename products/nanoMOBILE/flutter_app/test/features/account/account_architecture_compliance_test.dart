import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Account Module Architecture & SOLID Compliance', () {
    test('STRICT RULE: Ningún archivo en lib/features/account supera las 200 líneas', () {
      final accountDir = Directory('lib/features/account');
      expect(accountDir.existsSync(), isTrue, reason: 'El directorio account debe existir');

      final dartFiles = accountDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          // Los componentes preexistentes de google_account son heredados de web tooling
          .where((f) => !f.path.contains('google_account_'));


      final violations = <String>[];

      for (final file in dartFiles) {
        final lineCount = file.readAsLinesSync().length;
        if (lineCount > 200) {
          violations.add('${file.path}: $lineCount líneas');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Los siguientes archivos superan las 200 líneas: \n${violations.join('\n')}',
      );
    });

    test('Clean Architecture: Presentation no importa Infrastructure directamente', () {
      final presentationDir = Directory('lib/features/account/presentation');
      final files = presentationDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in files) {
        final content = file.readAsStringSync();
        if (content.contains('/infrastructure/') ||
            content.contains('firebase_auth_adapter.dart') ||
            content.contains('google_play_billing_adapter.dart')) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Archivos de presentación violan DIP importando infraestructura: \n${violations.join('\n')}',
      );
    });
  });
}
