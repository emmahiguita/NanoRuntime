import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';

void main() {
  group('SettingsState Glass Properties', () {
    test('default glass properties are correct', () {
      const state = SettingsState();
      expect(state.glassEnabled, isTrue);
      expect(state.glassOpacity, closeTo(0.70, 0.001));
      expect(state.glassClarity, closeTo(0.85, 0.001));
      expect(state.glassBlur, closeTo(18.0, 0.001));
    });

    test('copyWith updates glass properties properly', () {
      const state = SettingsState();
      final updated = state.copyWith(
        glassEnabled: false,
        glassOpacity: 0.45,
        glassClarity: 0.95,
        glassBlur: 24.0,
      );

      expect(updated.glassEnabled, isFalse);
      expect(updated.glassOpacity, closeTo(0.45, 0.001));
      expect(updated.glassClarity, closeTo(0.95, 0.001));
      expect(updated.glassBlur, closeTo(24.0, 0.001));
    });
  });

  group('GlassSurface Widget', () {
    testWidgets('renders child content properly inside glass frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: GlassSurface(
              opacity: 0.65,
              clarity: 0.80,
              blur: 15.0,
              child: Text('Test Glass Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Glass Content'), findsOneWidget);
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('handles tap event with callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: GlassSurface(
              onTap: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(tapped, isTrue);
    });
  });

  group('Universal Glass Propagation', () {
    test('AppTheme.buildTheme injects glass settings into NanoThemeExtension', () {
      final customTheme = AppTheme.buildTheme(
        NanoDarkColors(),
        glassEnabled: true,
        glassOpacity: 0.55,
        glassClarity: 0.90,
        glassBlur: 28.0,
      );

      final extension = customTheme.extension<NanoThemeExtension>();
      expect(extension, isNotNull);
      expect(extension!.glassEnabled, isTrue);
      expect(extension.glassOpacity, closeTo(0.55, 0.001));
      expect(extension.glassClarity, closeTo(0.90, 0.001));
      expect(extension.glassBlur, closeTo(28.0, 0.001));
    });

    testWidgets('NanoOpticalSurface respects glassEnabled: false without blur', (
      tester,
    ) async {
      final customTheme = AppTheme.buildTheme(
        NanoDarkColors(),
        glassEnabled: false,
        glassOpacity: 0.50,
        glassClarity: 0.80,
        glassBlur: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: const Scaffold(
            body: NanoOpticalSurface(
              hasBackdropBlur: true,
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      final backdropFilter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      // When glassEnabled is false, sigma is 0.0
      expect(backdropFilter.filter.toString(), contains('ImageFilter.blur(0.0, 0.0'));
    });
  });
}

