import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/terminal/terminal_manual.dart';
import 'package:nanoai/features/terminal/terminal_types.dart';

void main() {
  group('TerminalManual', () {
    test('help without args prints general index and categories', () {
      final lines = <({String text, Ln type})>[];
      TerminalManual.printHelp([], (t, ty) => lines.add((text: t, type: ty)));

      expect(lines.isNotEmpty, isTrue);
      expect(lines.any((l) => l.text.contains('MANUAL Y REFERENCIA')), isTrue);
      expect(lines.any((l) => l.text.contains('SISTEMA')), isTrue);
      expect(lines.any((l) => l.text.contains('IA')), isTrue);
      expect(lines.any((l) => l.text.contains('DEVOPS')), isTrue);
    });

    test(
      'help <category> prints all commands in category with descriptions and examples',
      () {
        final categories = [
          'sistema',
          'archivos',
          'ia',
          'devops',
          'red',
          'monitor',
          'paquetes',
          'terminal',
        ];

        for (final cat in categories) {
          final lines = <({String text, Ln type})>[];
          TerminalManual.printHelp([
            cat,
          ], (t, ty) => lines.add((text: t, type: ty)));

          expect(lines.isNotEmpty, isTrue);
          expect(
            lines.any(
              (l) => l.text.contains('CATEGORÍA: ${cat.toUpperCase()}'),
            ),
            isTrue,
            reason: 'Categoría $cat debe tener su encabezado',
          );
          expect(
            lines.any((l) => l.text.startsWith('• ')),
            isTrue,
            reason: 'Categoría $cat debe contener viñetas de comandos',
          );
        }
      },
    );

    test('man <command> prints detailed documentation', () {
      final commands = [
        'ai',
        'infer',
        'tune',
        'docker',
        'kali',
        'ls',
        'grep',
        'wifi',
        'battery',
        'free',
      ];

      for (final cmd in commands) {
        final lines = <({String text, Ln type})>[];
        TerminalManual.printMan([
          cmd,
        ], (t, ty) => lines.add((text: t, type: ty)));

        expect(lines.isNotEmpty, isTrue);
        expect(
          lines.any(
            (l) => l.text.contains('MANUAL DE COMANDO: ${cmd.toUpperCase()}'),
          ),
          isTrue,
        );
        expect(lines.any((l) => l.text.contains('DESCRIPCIÓN:')), isTrue);
        expect(lines.any((l) => l.text.contains('SINTAXIS:')), isTrue);
        expect(lines.any((l) => l.text.contains('EJEMPLOS DE USO:')), isTrue);
      }
    });

    test('man without args and unknown commands return helpful error', () {
      final emptyLines = <({String text, Ln type})>[];
      TerminalManual.printMan(
        [],
        (t, ty) => emptyLines.add((text: t, type: ty)),
      );
      expect(emptyLines.any((l) => l.type == Ln.stderr), isTrue);

      final unknownLines = <({String text, Ln type})>[];
      TerminalManual.printMan([
        'nonexistent_cmd_xyz',
      ], (t, ty) => unknownLines.add((text: t, type: ty)));
      expect(unknownLines.any((l) => l.type == Ln.stderr), isTrue);
    });
  });
}
