import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/business/meta_template_content.dart';
import 'package:nanoai/features/automation/engine/business/meta_template_models.dart';
import 'package:nanoai/features/automation/presentation/business/meta_template_editor_dialog.dart';

const template = MetaMessageTemplate(
  id: 'remote-id',
  name: 'pedido',
  language: 'es_CO',
  category: 'UTILITY',
  status: 'APPROVED',
  components: [
    {
      'type': 'BODY',
      'text': 'Pedido {{1}}',
      'example': {
        'body_text': [
          ['123'],
        ],
      },
    },
    {'type': 'FOOTER', 'text': 'Atención al cliente'},
    {
      'type': 'BUTTONS',
      'buttons': [
        {'type': 'QUICK_REPLY', 'text': 'Gracias'},
      ],
    },
  ],
);

void main() {
  test('editar texto preserva ejemplos, botones y el original', () {
    final edited = MetaTemplateContent.withBody(
      template.components,
      'Nuevo {{1}}',
    );
    expect(edited.first['example'], template.components.first['example']);
    expect(edited.last, template.components.last);
    expect(template.components.first['text'], 'Pedido {{1}}');
    expect(MetaTemplateContent.body(edited), 'Nuevo {{1}}');
  });

  for (final size in [const Size(360, 740), const Size(740, 360)]) {
    testWidgets('editor guarda sin desbordar en $size con texto grande', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MetaMessageTemplateDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  draft = await showDialog<MetaMessageTemplateDraft>(
                    context: context,
                    builder: (_) =>
                        const MetaTemplateEditorDialog(initial: template),
                  );
                },
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      final body = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Cuerpo del mensaje',
      );
      await tester.ensureVisible(body);
      await tester.enterText(body, 'Actualizado {{1}}');
      await tester.pump();
      await tester.tap(find.text('Enviar a Meta'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(draft, isNotNull);
      expect(draft!.components.first['text'], 'Actualizado {{1}}');
      expect(draft!.components.last, template.components.last);
    });
  }
}
