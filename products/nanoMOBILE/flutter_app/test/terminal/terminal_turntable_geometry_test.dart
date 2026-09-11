import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/terminal/domain/terminal_hub_card.dart';
import 'package:nanoai/features/terminal/presentation/widgets/interactive_3d_turntable_box.dart';

const card = TerminalHubCard(
  id: 'terminal', title: 'Terminal', eyebrow: 'LINUX',
  description: 'Terminal Linux con herramientas reales y entorno local.',
  icon: Icons.terminal, accent: Colors.cyan, route: '/terminal',
  highlights: ['Soporte completo ANSI 256 colores y emulación VT100', 'Gestor PTY multisesión con buffer desacoplado', 'Atajos rápidos personalizables y barra de modificadores'], actionLabel: 'Abrir',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final (family, path) in [
      ('Inter', 'assets/fonts/Inter-Regular.ttf'),
      ('monospace', 'assets/fonts/JetBrainsMono-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  for (final compact in [false, true]) {
    testWidgets('closed box keeps its stage through 360 degrees compact=$compact', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      var angle = 0.0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(backgroundColor: const Color(0xFF243247), body: Center(
          child: RepaintBoundary(key: boundary, child: Interactive3DTurntableBox(
            card: card, autoRotate: false,
            width: compact ? 165 : 200, height: compact ? 225 : 275,
            onRotationChanged: (value) => angle = value,
          )),
        )),
      ));
      await tester.pump();
      final box = find.byType(Interactive3DTurntableBox);
      final initialSize = tester.getSize(box);
      final gestureFinder = find.descendant(of: box, matching: find.byType(GestureDetector)).first;
      final gestureWidget = tester.widget<GestureDetector>(gestureFinder);
      // Exercise caps as well as spines, at both pitch limits.
      gestureWidget.onPanUpdate!(DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(0, compact ? -100 : 100)));
      for (var step = 0; step <= 24; step++) {
        if (step > 0) {
          gestureWidget.onPanStart!(DragStartDetails());
          gestureWidget.onPanUpdate!(DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(math.pi / 12 / 0.015, 0)));
          gestureWidget.onPanCancel!();
        }
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'angle $step * 15 degrees');
        expect(tester.getSize(box), initialSize);
        // A convex box always exposes at least one, and at most three faces.
        final faces = find.byWidgetPredicate((w) => w is Transform && w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('3d_box_'));
        expect(faces.evaluate().length, inInclusiveRange(1, 3));
        final front = find.byKey(const ValueKey('3d_box_face_front'));
        final left = find.byKey(const ValueKey('3d_box_spine_left'));
        if (front.evaluate().isNotEmpty && left.evaluate().isNotEmpty) {
          final frontBox = tester.renderObject<RenderTransform>(front).child!;
          final leftBox = tester.renderObject<RenderTransform>(left).child!;
          for (final y in [0.0, compact ? 225.0 : 275.0]) {
            expect((frontBox.localToGlobal(Offset(0, y)) -
                leftBox.localToGlobal(Offset(26, y))).distance,
                lessThan(0.001), reason: 'front/spine edge must share vertices');
          }
        }
        final capture = Platform.environment['NANO_3D_CAPTURE'];
        if (capture != null && step % 3 == 0) {
          await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$capture/box-${compact ? 'small' : 'large'}-${step * 15}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          });
        }
      }
      expect(math.sin(angle), closeTo(0, 0.0001));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
