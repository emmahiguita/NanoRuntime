import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/agent/agent_result.dart';
import 'package:nanoai/core/agent/nano_selector.dart';
import 'package:nanoai/core/agent/nano_snapshot.dart';
import 'package:nanoai/core/agent/selector_engine.dart';

import 'fixtures.dart';

void main() {
  final engine = NanoSelectorEngine();

  NanoSnapshot snap(String name) => NanoSnapshot.fromRaw(switch (name) {
        'ajustes' => snapshotAjustes(),
        'dobleAceptar' => snapshotDobleAceptar(),
        'labelCampo' => snapshotLabelCampo(),
        'centroVsEsquina' => snapshotCentroVsEsquina(),
        'idDiscrepante' => snapshotIdDiscrepante(),
        'rebind' => snapshotRebindEmpty(),
        _ => throw ArgumentError(name),
      });

  group('NanoSelectorEngine.resolve', () {
    test('resourceId exacto gana sobre texto (100)', () {
      final r = engine.resolve(
        const NanoSelector(
          resourceId: 'com.android.settings:id/button1',
          text: 'Aceptar',
        ),
        snap('ajustes'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.node.id, 'com.android.settings:id/button1');
      expect(r.best!.score, greaterThanOrEqualTo(100));
      expect(r.best!.matchedCriteria, contains('resourceId:+100'));
    });

    test('desc exacta da 90', () {
      final r = engine.resolve(
        const NanoSelector(description: 'Buscar ajustes'),
        snap('ajustes'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.score, 90);
      expect(r.best!.matchedCriteria, contains('desc:+90'));
    });

    test('texto exacto 75 vs contains 65', () {
      final exact = engine.resolve(
        const NanoSelector(text: 'Bluetooth'),
        snap('ajustes'),
      );
      expect(exact.best!.score, 75);

      final fuzzyRes = engine.resolve(
        const NanoSelector(text: 'luetoot', textMatcher: TextMatcher.contains),
        snap('ajustes'),
      );
      expect(fuzzyRes.best!.score, 65);
      expect(fuzzyRes.best!.matchedCriteria, contains('textFuzzy:+65'));
    });

    test('role + texto suma 85', () {
      final r = engine.resolve(
        const NanoSelector(role: Role.textView, text: 'Ajustes'),
        snap('ajustes'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.score, 85);
      expect(r.best!.matchedCriteria, containsAll(['textExact:+75', 'role:+10']));
    });

    test('editable: primer campo visible suma 60', () {
      final r = engine.resolve(
        const NanoSelector(editable: true),
        snap('ajustes'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.node.editable, isTrue);
      expect(r.best!.score, 60);
      expect(r.best!.matchedCriteria,
          containsAll(['editable:+45', 'firstEditable:+15']));
    });

    test('near: campo junto a label ancla gana +50', () {
      final r = engine.resolve(
        const NanoSelector(
          editable: true,
          near: NanoSelector(description: 'Usuario'),
        ),
        snap('labelCampo'),
      );
      expect(r.isResolved, isTrue);
      // 45 editable + 15 primer editable + 50 near = 110.
      expect(r.best!.score, 110);
      expect(r.best!.matchedCriteria, contains('near:+50'));
    });

    test('near sin near → sin bonus (solo 60)', () {
      final r = engine.resolve(
        const NanoSelector(editable: true),
        snap('labelCampo'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.score, 60);
      expect(r.best!.matchedCriteria, isNot(contains('near:+50')));
    });

    test('near: ancla del sub-selector no coincide → sin bonus', () {
      final r = engine.resolve(
        const NanoSelector(
          editable: true,
          near: NanoSelector(description: 'Contraseña'),
        ),
        snap('labelCampo'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.score, 60);
    });

    test('near: contenedor raíz que envuelve todo NO ancla hijos', () {
      // Root FrameLayout coincide por texto "Ajustes"... no: usamos ancla por
      // desc inexistente en root. Aquí: root envuelve el EditText, pero el
      // gap vertical del root es -1 (solape) → sin bonus.
      final snapRaw = snapshotLabelCampo();
      // Ancla = root (FrameLayout) con desc única inventada.
      (snapRaw['nodes'] as List)[0]['desc'] = 'RootAncla';
      final r = engine.resolve(
        const NanoSelector(
          editable: true,
          near: NanoSelector(description: 'RootAncla'),
        ),
        NanoSnapshot.fromRaw(snapRaw),
      );
      expect(r.isResolved, isTrue);
      // Sin near: el root solapa al campo en el eje vertical → no ancla.
      expect(r.best!.score, 60);
      expect(r.best!.matchedCriteria, isNot(contains('near:+50')));
    });

    test('centerRegion: dos nodos iguales, gana el central (gap 10)', () {
      final r = engine.resolve(
        const NanoSelector(text: 'Centro'),
        snap('centroVsEsquina'),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.score, 85); // 75 texto + 10 centro
      expect(r.best!.node.bounds.centerX, 540);
      expect(r.best!.matchedCriteria, contains('center:+10'));
    });

    test('resourceId sin match excluye aunque el texto coincida', () {
      final r = engine.resolve(
        const NanoSelector(
          resourceId: 'com.ejemplo.app:id/enviar',
          text: 'Enviar',
        ),
        snap('idDiscrepante'),
      );
      expect(r.status, ResolveStatus.notFound);
    });

    test('package mismatch → notFound (precondición dura)', () {
      final r = engine.resolve(
        const NanoSelector(
          packageName: 'com.whatsapp',
          text: 'Bluetooth',
        ),
        snap('ajustes'),
      );
      expect(r.status, ResolveStatus.notFound);
      expect(r.reason, contains('com.whatsapp'));
    });

    test('dos "Aceptar" idénticos → ambiguous (gap 0)', () {
      final r = engine.resolve(
        const NanoSelector(text: 'Aceptar'),
        snap('dobleAceptar'),
      );
      expect(r.status, ResolveStatus.ambiguous);
      expect(r.candidates.length, 2);
    });

    test('evidencia diferenciadora ≥ gap → resolved', () {
      // El botón con desc "Confirmar" suma 90 extra → gap 90 ≥ 10.
      final snapRaw = snapshotDobleAceptar();
      (snapRaw['nodes'] as List)[1]['desc'] = 'Confirmar';
      final r = engine.resolve(
        const NanoSelector(description: 'Confirmar', text: 'Aceptar'),
        NanoSnapshot.fromRaw(snapRaw),
      );
      expect(r.isResolved, isTrue);
      expect(r.best!.score, 165);
    });

    test('expectedCount=2 con dos candidatos → resolved', () {
      final r = engine.resolve(
        const NanoSelector(text: 'Aceptar', expectedCount: 2),
        snap('dobleAceptar'),
      );
      expect(r.isResolved, isTrue);
    });

    test('expectedCount=2 con tercero pegado → ambiguous', () {
      final snapRaw = snapshotDobleAceptar();
      (snapRaw['nodes'] as List).add({
        'id': '',
        'type': 'android.widget.Button',
        'text': 'Aceptar',
        'desc': '',
        'clickable': true,
        'editable': false,
        'scrollable': false,
        'checked': false,
        'focusable': false,
        'focused': false,
        'visible': true,
        'enabled': true,
        'bounds': [860, 1200, 1060, 1300],
        'depth': 2,
      });
      final r = engine.resolve(
        const NanoSelector(text: 'Aceptar', expectedCount: 2),
        NanoSnapshot.fromRaw(snapRaw),
      );
      // 75/75/75: gap entre 2º y 3º = 0 < 10 → ambiguous.
      expect(r.status, ResolveStatus.ambiguous);
    });

    test('snapshot vacío → notFound', () {
      final r = engine.resolve(
        const NanoSelector(text: 'Ajustes'),
        snap('rebind'),
      );
      expect(r.status, ResolveStatus.notFound);
    });

    test('candidato bajo umbral mínimo → notFound', () {
      // role + center + clickable = 30 < 40 → no entra al ranking.
      final r = engine.resolve(
        const NanoSelector(role: Role.button, clickable: true),
        snap('ajustes'),
      );
      expect(r.status, ResolveStatus.notFound);
    });

    test('minResolvedScore configurable', () {
      final strict = NanoSelectorEngine(minResolvedScore: 80);
      final r = strict.resolve(
        const NanoSelector(text: 'Bluetooth'),
        snap('ajustes'),
      );
      // 75 < 80 → notFound con el engine estricto.
      expect(r.status, ResolveStatus.notFound);
    });

    test('nodos invisibles o deshabilitados quedan fuera', () {
      final snapRaw = snapshotAjustes();
      // El Bluetooth visible pasa a invisible → no debe ganar.
      (snapRaw['nodes'] as List)[4]['visible'] = false;
      final r = engine.resolve(
        const NanoSelector(text: 'Bluetooth'),
        NanoSnapshot.fromRaw(snapRaw),
      );
      expect(r.status, ResolveStatus.notFound);
    });
  });

  group('NanoSelector', () {
    test('sin criterios → SelectorFormatException', () {
      expect(() => const NanoSelector().validate(),
          throwsA(isA<SelectorFormatException>()));
    });

    test('regex inválido → SelectorFormatException', () {
      expect(
        () => const NanoSelector(
          text: 'h[',
          textMatcher: TextMatcher.regex,
        ).validate(),
        throwsA(isA<SelectorFormatException>()),
      );
    });
  });

  group('NanoSelector.parse (mini-DSL)', () {
    test('texto simple → text exact', () {
      final s = NanoSelector.parse('Ajustes');
      expect(s.text, 'Ajustes');
      expect(s.textMatcher, TextMatcher.exact);
    });

    test('text= explícito', () {
      expect(NanoSelector.parse('text=Buscar').text, 'Buscar');
    });

    test('text~= → contains', () {
      final s = NanoSelector.parse('text~=buscar');
      expect(s.text, 'buscar');
      expect(s.textMatcher, TextMatcher.contains);
    });

    test('text/= → regex', () {
      final s = NanoSelector.parse(r'text/=h[ae]la');
      expect(s.textMatcher, TextMatcher.regex);
    });

    test('id= y pkg= combinados', () {
      final s = NanoSelector.parse(
        'pkg=com.android.settings;id=com.android.settings:id/button1',
      );
      expect(s.packageName, 'com.android.settings');
      expect(s.resourceId, 'com.android.settings:id/button1');
    });

    test('role=button;text=ok', () {
      final s = NanoSelector.parse('role=button;text=ok');
      expect(s.role, Role.button);
      expect(s.text, 'ok');
    });

    test('clave desconocida → FormatException', () {
      expect(() => NanoSelector.parse('foo=bar'),
          throwsA(isA<SelectorFormatException>()));
    });

    test('rol desconocido → FormatException', () {
      expect(() => NanoSelector.parse('role=taco'),
          throwsA(isA<SelectorFormatException>()));
    });

    test('expresión vacía → FormatException', () {
      expect(() => NanoSelector.parse('   '),
          throwsA(isA<SelectorFormatException>()));
    });

    test('solo pkg sin criterio → FormatException', () {
      expect(() => NanoSelector.parse('pkg=com.android.settings'),
          throwsA(isA<SelectorFormatException>()));
    });

    test('editable=true;near=desc=Usuario → near anidado', () {
      final s = NanoSelector.parse('editable=true;near=desc=Usuario');
      expect(s.editable, isTrue);
      expect(s.near, isNotNull);
      expect(s.near!.description, 'Usuario');
      expect(s.near!.text, isNull);
    });

    test('near con texto simple (sin =) → text exact anidado', () {
      final s = NanoSelector.parse('editable=true;near=Usuario');
      expect(s.near!.text, 'Usuario');
      expect(s.near!.textMatcher, TextMatcher.exact);
    });
  });
}
