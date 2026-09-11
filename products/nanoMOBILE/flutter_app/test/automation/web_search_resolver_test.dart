import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/browser/web_search_resolver.dart';

void main() {
  const resolver = WebSearchResolver();

  group('WebSearchResolver — Pruebas de resolución de intenciones', () {
    test('resuelve "busca en chrome noticias de inteligencia artificial"', () {
      final plan = resolver.resolve('busca en chrome noticias de inteligencia artificial');
      expect(plan, isNotNull);
      expect(plan!.query, 'noticias de inteligencia artificial');
      expect(
        plan.targetUrl,
        'https://www.google.com/search?q=noticias%20de%20inteligencia%20artificial',
      );
      expect(plan.call.tool, 'open_url');
      expect(plan.call.args?['packageName'], 'com.android.chrome');
      expect(plan.expectation.expectedPackage, 'com.android.chrome');
    });

    test('resuelve "busca en google el clima de hoy"', () {
      final plan = resolver.resolve('busca en google el clima de hoy');
      expect(plan, isNotNull);
      expect(plan!.query, 'el clima de hoy');
      expect(
        plan.targetUrl,
        'https://www.google.com/search?q=el%20clima%20de%20hoy',
      );
    });

    test('resuelve "abre Chrome y busca fotos de gatos"', () {
      final plan = resolver.resolve('abre Chrome y busca fotos de gatos');
      expect(plan, isNotNull);
      expect(plan!.query, 'fotos de gatos');
      expect(
        plan.targetUrl,
        'https://www.google.com/search?q=fotos%20de%20gatos',
      );
    });

    test('resuelve "busca recetas de pizza en internet"', () {
      final plan = resolver.resolve('busca recetas de pizza en internet');
      expect(plan, isNotNull);
      expect(plan!.query, 'recetas de pizza');
      expect(
        plan.targetUrl,
        'https://www.google.com/search?q=recetas%20de%20pizza',
      );
    });

    test('resuelve "investiga en internet sobre marte"', () {
      final plan = resolver.resolve('investiga en internet sobre marte');
      expect(plan, isNotNull);
      expect(plan!.query, 'marte');
      expect(
        plan.targetUrl,
        'https://www.google.com/search?q=marte',
      );
    });

    test('resuelve "search on google flutter developer guide"', () {
      final plan = resolver.resolve('search on google flutter developer guide');
      expect(plan, isNotNull);
      expect(plan!.query, 'flutter developer guide');
      expect(
        plan.targetUrl,
        'https://www.google.com/search?q=flutter%20developer%20guide',
      );
    });

    test('ignora búsquedas de aplicaciones no web como YouTube o Spotify', () {
      final plan1 = resolver.resolve('busca en youtube tutorial de flutter');
      expect(plan1, isNull);

      final plan2 = resolver.resolve('busca en spotify musica clasica');
      expect(plan2, isNull);

      final plan3 = resolver.resolve('busca a Juan en WhatsApp');
      expect(plan3, isNull);
    });

    test('ignora frases vacías o sin consulta', () {
      expect(resolver.resolve(''), isNull);
      expect(resolver.resolve('busca en chrome'), isNull);
      expect(resolver.resolve('abre chrome'), isNull);
    });
  });
}
