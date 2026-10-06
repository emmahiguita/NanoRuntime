import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';

/// Regresión: claves cortas del catálogo (p.ej. 'chat') NO deben secuestrar
/// nombres de apps que las contienen como subcadena ("chatgpt").
void main() {
  const catalog = defaultDeterministicCatalog;

  String? firstTool(String goal) => catalog.forGoal(goal)?.steps.first.tool;

  test('"abre chatgpt" no cae en el flujo de WhatsApp', () {
    expect(firstTool('abre chatgpt'), isNot('whatsapp.open_chat'));
    expect(catalog.forGoal('abre chatgpt'), isNull);
  });

  test('"abre telegram" no es capturado por el catálogo', () {
    expect(catalog.forGoal('abre telegram'), isNull);
  });

  test('"abre whatsapp" sigue resolviendo a launch_app', () {
    expect(firstTool('abre whatsapp'), 'launch_app');
  });

  test('"abre el chat de juan" sigue resolviendo a whatsapp.open_chat', () {
    expect(firstTool('abre el chat de juan'), 'whatsapp.open_chat');
  });

  test('plural simple sigue funcionando (archivos → archivo)', () {
    expect(catalog.forGoal('lista los archivos'), isNotNull);
  });
}
