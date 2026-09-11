import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/browser/chrome_content_extractor.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

NanoNode _makeNode({
  required int index,
  required int depth,
  String id = '',
  String type = 'android.view.View',
  String text = '',
  String description = '',
  NanoBounds bounds = const NanoBounds(left: 0, top: 0, right: 100, bottom: 100),
}) {
  return NanoNode(
    index: index,
    depth: depth,
    packageName: 'com.android.chrome',
    id: id,
    type: type,
    text: text,
    description: description,
    clickable: false,
    editable: false,
    scrollable: false,
    checked: false,
    focusable: false,
    focused: false,
    visible: true,
    enabled: true,
    bounds: bounds,
  );
}

void main() {
  const extractor = ChromeContentExtractor();

  group('ChromeContentExtractor — Extracción de texto web limpio', () {
    test('extrae párrafos reales y descarta controles de Chrome (url_bar, tab_switcher, etc.)', () {
      final snapshot = NanoSnapshot(
        package: 'com.android.chrome',
        nodes: [
          // 1. Barra de direcciones
          _makeNode(
            index: 0,
            depth: 1,
            id: 'com.android.chrome:id/url_bar',
            type: 'android.widget.EditText',
            text: 'https://es.wikipedia.org/wiki/Inteligencia_artificial',
            bounds: const NanoBounds(left: 100, top: 50, right: 900, bottom: 120),
          ),
          // 2. Botón de pestañas
          _makeNode(
            index: 1,
            depth: 1,
            id: 'com.android.chrome:id/tab_switcher_button',
            type: 'android.widget.ImageButton',
            description: 'Cambiar o cerrar pestañas',
            bounds: const NanoBounds(left: 920, top: 50, right: 1000, bottom: 120),
          ),
          // 3. Menú de Chrome
          _makeNode(
            index: 2,
            depth: 1,
            id: 'com.android.chrome:id/menu_button',
            type: 'android.widget.ImageButton',
            description: 'Más opciones',
            bounds: const NanoBounds(left: 1010, top: 50, right: 1080, bottom: 120),
          ),
          // 4. Encabezado del artículo en la web
          _makeNode(
            index: 3,
            depth: 2,
            id: '',
            type: 'android.widget.TextView',
            text: 'Inteligencia artificial en la era moderna',
            bounds: const NanoBounds(left: 50, top: 200, right: 1030, bottom: 260),
          ),
          // 5. Párrafo 1 del artículo
          _makeNode(
            index: 4,
            depth: 2,
            id: '',
            type: 'android.view.View',
            text: 'La inteligencia artificial es una rama de la ciencia de la computación que busca crear sistemas capaces de realizar tareas que requieren inteligencia humana.',
            bounds: const NanoBounds(left: 50, top: 280, right: 1030, bottom: 420),
          ),
          // 6. Párrafo 2 del artículo
          _makeNode(
            index: 5,
            depth: 2,
            id: '',
            type: 'android.view.View',
            text: 'Los modelos de lenguaje y la visión por computadora son ejemplos clave de su avance exponencial en los últimos años.',
            bounds: const NanoBounds(left: 50, top: 440, right: 1030, bottom: 580),
          ),
        ],
      );

      final result = extractor.extract(snapshot);

      expect(result.isNotEmpty, isTrue);
      expect(result.url, 'https://es.wikipedia.org/wiki/Inteligencia_artificial');
      expect(result.title, 'Inteligencia artificial en la era moderna');
      expect(result.paragraphs.length, 3);
      expect(result.paragraphs[0], 'Inteligencia artificial en la era moderna');
      expect(
        result.paragraphs[1],
        contains('La inteligencia artificial es una rama'),
      );
      expect(
        result.paragraphs[2],
        contains('Los modelos de lenguaje'),
      );
      expect(result.rawText, isNot(contains('Cambiar o cerrar pestañas')));
      expect(result.rawText, isNot(contains('Más opciones')));
    });

    test('devuelve contenido vacío cuando el snapshot está vacío', () {
      final snapshot = NanoSnapshot(package: '', nodes: []);
      final result = extractor.extract(snapshot);
      expect(result.isEmpty, isTrue);
      expect(result.paragraphs, isEmpty);
      expect(result.rawText, isEmpty);
    });
  });
}
