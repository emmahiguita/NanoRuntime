import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/models/presentation/widgets/model_info_button.dart';

void main() {
  testWidgets('funciona sin Overlay y conserva una etiqueta accesible', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ModelInfoButton(
            icon: Icons.refresh,
            label: 'Escanear almacenamiento',
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Escanear almacenamiento'), findsOneWidget);
    await tester.tap(find.byType(ModelInfoButton));
    expect(taps, 1);

    semantics.dispose();
  });
}
