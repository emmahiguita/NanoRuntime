import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/account/presentation/widgets/login_access_form.dart';
import 'package:nanoai/features/account/presentation/widgets/login_page_layout.dart';
import 'package:nanoai/features/account/presentation/widgets/frost_login_surface.dart';

/// Valida espacio real, fuente ampliada y acciones sin instalar ni borrar apps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // La inspección visual usa tipografía real, no la fuente cuadrada de pruebas.
    final text = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await text.load();
    await icons.load();
  });
  for (final spec in [
    ('portrait', const Size(360, 780), Brightness.dark, 1.0),
    ('landscape', const Size(840, 390), Brightness.dark, 1.0),
    ('small_large_text', const Size(320, 568), Brightness.light, 1.35),
  ]) {
    testWidgets('Acceso legible: ${spec.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = spec.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final email = TextEditingController(), password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);
      var localCalls = 0;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff477be9),
              brightness: spec.$3,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(spec.$4)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: capture,
            child: FrostLoginSurface(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: LoginPageLayout(
                    form: Form(
                      child: LoginAccessForm(
                        email: email,
                        password: password,
                        busy: false,
                        onLogin: () {},
                        onGoogle: () {},
                        onLocal: () => localCalls++,
                        onForgot: () {},
                      ),
                    ),
                    footer: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('¿No tienes cuenta?'),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Crear cuenta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const ResizeImage(
            AssetImage('assets/nano/login_frost_owl.png'),
            width: 1000,
          ),
          tester.element(find.byType(LoginPageLayout)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      // Imagen de la composición real para inspección visual antes de instalar.
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/login_${spec.$1}.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      final local = find.text('Continuar en este dispositivo');
      await tester.ensureVisible(local);
      await tester.pumpAndSettle();
      await tester.tap(local);
      expect(localCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
