import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/linux_voice_command_parser.dart';

void main() {
  const parser = LinuxVoiceCommandParser();

  group('lista archivos → linux.list(path)', () {
    test('"lista los archivos de la raíz" → linux.list("/")', () {
      final r = parser.parse('lista los archivos de la raíz');
      expect(r, isNotNull);
      expect(r!.call.tool, 'linux.list');
      expect(r.call.text, '/');
    });

    test('"muestra los archivos de este directorio" → linux.list("/")', () {
      final r = parser.parse('muestra los archivos de este directorio');
      expect(r!.call.tool, 'linux.list');
      expect(r.call.text, '/');
    });

    test('"lista los archivos de /tmp" → linux.list("/tmp")', () {
      final r = parser.parse('lista los archivos de /tmp');
      expect(r!.call.tool, 'linux.list');
      expect(r.call.text, '/tmp');
    });
  });

  group('crear archivo → linux.writeFile (typed, no bash -c)', () {
    test('"crea un archivo llamado prueba.txt con el texto hola"', () {
      final r = parser.parse('crea un archivo llamado prueba.txt con el texto hola');
      expect(r, isNotNull);
      expect(r!.call.tool, 'linux.writeFile');
      expect(r.call.text, '/tmp/prueba.txt');
      expect(r.call.args?['content'], 'hola');
      // Verificación: FileExists + FileContentContains (no solo exitCode).
      expect(r.expectation, isNotNull);
      expect(r.expectation!.statePredicates, hasLength(2));
    });

    test('"escribe hola en nota.txt" NO es write (orden invertido no soportado)',
        () {
      // El parser no cubre el orden invertido; debe caer a otro camino (null),
      // nunca a un write mal tipado.
      final r = parser.parse('escribe hola en nota.txt');
      expect(r, isNull);
    });
  });

  group('leer archivo → linux.readFile', () {
    test('"lee prueba.txt" → linux.readFile("/tmp/prueba.txt")', () {
      final r = parser.parse('lee prueba.txt');
      expect(r!.call.tool, 'linux.readFile');
      expect(r.call.text, '/tmp/prueba.txt');
    });

    test('"léelo" sin contexto → null (no inventa target)', () {
      final r = parser.parse('léelo');
      expect(r, isNull);
    });

    test('"léelo" con contexto → linux.readFile(lastPath)', () {
      final r = parser.parse('léelo', lastFilePath: '/tmp/prueba.txt');
      expect(r!.call.tool, 'linux.readFile');
      expect(r.call.text, '/tmp/prueba.txt');
    });
  });

  group('no es comando Linux', () {
    test('"abre bluetooth" → null (no toca Linux)', () {
      expect(parser.parse('abre bluetooth'), isNull);
    });

    test('"hola cómo estás" → null', () {
      expect(parser.parse('hola cómo estás'), isNull);
    });
  });
}
