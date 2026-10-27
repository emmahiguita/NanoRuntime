import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/widgets/navigation/nano_keyboard_dock_gate.dart';

// Regresión del bloqueo observado en el teléfono: el editor visible no recibía
// foco. Esta prueba de widget NO acredita apertura ni envío real por WhatsApp.
void main() {
  testWidgets('permite enfocar y escribir sin ocultar el editor con teclado', (
    tester,
  ) async {
    final editorFocus = FocusNode();
    addTearDown(editorFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NanoKeyboardDockGate(child: TextField(focusNode: editorFocus)),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(editorFocus.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), '@whatsapp Emm');
    expect(find.text('@whatsapp Emm'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
  });
}
