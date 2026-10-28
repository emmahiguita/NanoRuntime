import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/ui_context_guard.dart';
import 'package:nanoai/features/automation/application/whatsapp_chat_export_preparer.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/planning/whatsapp_automation_input.dart';

/// Árbol doble explícito: comprueba límites y planificación, no genera ni
/// acredita archivos reales. La ruta de menús se exploró en el OPPO físico.
NanoSnapshot chat({
  String pkg = 'com.whatsapp',
  bool truncated = false,
  int editorWindow = 4,
  String root = 'root-chat',
  String menu = 'Más opciones',
}) => NanoSnapshot.fromRaw({
  'package': pkg,
  'truncated': truncated,
  'nodes': [
    {
      'package': pkg,
      'desc': menu,
      'visible': true,
      'enabled': true,
      'windowId': 4,
      'rootIdentity': 'root-chat',
    },
    {
      'package': pkg,
      'id': '$pkg:id/conversation_contact_name',
      'text': 'Prueba',
      'visible': true,
      'enabled': true,
      'windowId': 4,
      'rootIdentity': 'root-chat',
    },
    {
      'package': pkg,
      'id': '$pkg:id/entry',
      'editable': true,
      'visible': true,
      'enabled': true,
      'windowId': editorWindow,
      'rootIdentity': root,
    },
  ],
});

/// Protege la frontera entre abrir exportación, guardar y enviar a un contacto.
void main() {
  test(
    'cada tap conserva la cabecera y raíz y rechaza otro chat antes de actuar',
    () {
      final prepared = WhatsAppChatExportPreparer.prepare(chat());
      for (final step in prepared.plan!) {
        final guard = step.args!['contextGuard'];
        expect(UiContextGuard.failure(chat(), guard), isNull);
        final other = chat();
        final raw = {
          'package': 'com.whatsapp',
          'nodes': [
            {
              'package': 'com.whatsapp',
              'id': 'com.whatsapp:id/conversation_contact_name',
              'text': 'Otro contacto',
              'visible': true,
              'enabled': true,
              'windowId': 4,
              'rootIdentity': 'root-chat',
            },
          ],
        };
        expect(
          UiContextGuard.failure(NanoSnapshot.fromRaw(raw), guard),
          isNotNull,
        );
        expect(
          UiContextGuard.failure(other, {'package': 'com.whatsapp'}),
          isNotNull,
        );
      }
    },
  );
  test('sin chat, otra app o lectura parcial no hay exportación', () {
    for (final snapshot in [
      null,
      chat(pkg: 'otra.app'),
      chat(truncated: true),
    ]) {
      expect(
        () => WhatsAppChatExportPreparer.prepare(snapshot),
        throwsFormatException,
      );
    }
  });
  test('no mezcla una cabecera y un editor de ventanas distintas', () {
    expect(
      () => WhatsAppChatExportPreparer.prepare(chat(editorWindow: 5)),
      throwsFormatException,
    );
    expect(
      () => WhatsAppChatExportPreparer.prepare(chat(root: 'otro-chat')),
      throwsFormatException,
    );
  });
  test('el plan se detiene en exportación oficial sin guardar ni enviar', () {
    final prepared = WhatsAppChatExportPreparer.prepare(chat());
    expect(prepared.plan, hasLength(3));
    expect(prepared.plan!.every((step) => step.tool == 'tap'), isTrue);
    expect(prepared.plan!.last.expect!['appear'], contains('Sin archivos'));
    expect(prepared.goal.text, contains('Aún no se ha guardado'));
  });
  test(
    'seleccionar WhatsApp conserva la orden de exportar para el coordinador',
    () {
      expect(
        WhatsAppAutomationInput.command('Exporta esta conversación'),
        'Exporta el chat actual de WhatsApp',
      );
      expect(
        () =>
            WhatsAppAutomationInput.command('Exporta el chat de Otra Persona'),
        throwsFormatException,
      );
    },
  );
  test('la comprobación final sigue el idioma del menú observado', () {
    final prepared = WhatsAppChatExportPreparer.prepare(
      chat(menu: 'More options'),
    );
    expect(prepared.goal.expectation!.visibleText, 'Without media');
    expect(
      () => WhatsAppChatExportPreparer.prepare(chat(menu: 'Menú desconocido')),
      throwsFormatException,
    );
  });
}
