import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/models/presentation/widgets/model_screen_helpers.dart';
import 'package:nanoai/features/models/presentation/widgets/models_carousel_card.dart';

void main() {
  const model = RecommendedModelCardData(
    title: 'Modelo Liquid con un nombre deliberadamente muy largo',
    params: '3.12B',
    quantization: 'Q4_K_M',
    downloadSize: '1.85 GB',
    memoryReference: 'RAM estimada ≈2.1 GB',
    description: 'Motor LLAMA.CPP',
    deviceEvidence: 'CPH2557: rendimiento pendiente de medir',
    isDefault: false,
  );

  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
      child: Scaffold(body: SizedBox(width: 320, child: child)),
    ),
  );

  testWidgets('carousel card does not overflow on narrow large text layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(height: 244, child: ModelsCarouselCard(model: model)),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('permission banner stacks its action instead of overlapping', (
    tester,
  ) async {
    await tester.pumpWidget(host(IosPermissionBanner(onRequestAccess: () {})));

    expect(tester.takeException(), isNull);
    expect(find.text('Permitir'), findsOneWidget);
  });
}
