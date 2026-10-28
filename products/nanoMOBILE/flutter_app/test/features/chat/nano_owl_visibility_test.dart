import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/chat/nano_everywhere/nano_ai_controller.dart';
import 'package:nanoai/features/chat/nano_everywhere/nano_ai_models.dart';
import 'package:nanoai/features/chat/nano_everywhere/nano_floating_wrapper.dart';
import 'support/nano_owl_test_ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arrancar y recrear el controlador no muestra el búho', () {
    for (var instance = 0; instance < 2; instance++) {
      final controller = NanoAiController(
        providers: const [],
        nativeApps: NanoTestNativeApps(),
        actions: NanoTestActions(),
      );
      expect(controller.isVisible, isFalse);
      expect(controller.checkAndClearExpandRequest(), isFalse);
      controller.reportStatus('Motor disponible');
      expect(controller.isVisible, isFalse);
      controller.dispose();
    }
  });

  test(
    'solo una apertura explícita muestra el panel; ocultar revoca abrir',
    () {
      final controller = NanoAiController(
        providers: const [],
        nativeApps: NanoTestNativeApps(),
        actions: NanoTestActions(),
      );
      addTearDown(controller.dispose);
      controller.expand();
      expect(controller.isVisible, isTrue);
      expect(controller.checkAndClearExpandRequest(), isTrue);
      expect(controller.checkAndClearExpandRequest(), isFalse);
      controller.hide();
      controller.reportStatus('Regreso a Nano');
      expect(controller.isVisible, isFalse);
      expect(controller.checkAndClearExpandRequest(), isFalse);
    },
  );

  test(
    'ocultar no interrumpe ni repite la acción que trabaja fuera de Nano',
    () async {
      final actions = NanoTestActions();
      final controller = NanoAiController(
        providers: const [],
        nativeApps: NanoTestNativeApps(),
        actions: actions,
      );
      addTearDown(controller.dispose);
      controller.expand();
      final request = controller.submit(
        'Abre WhatsApp',
        requestedMode: NanoMode.action,
      );
      controller.hide();
      expect(controller.isBusy, isTrue);
      expect(actions.cancellations, 0);
      actions.result.complete('[completedUnverified] Apertura solicitada');
      await request;
      expect(actions.calls, 1);
      expect(controller.isBusy, isFalse);
      expect(controller.isVisible, isFalse);
    },
  );

  testWidgets(
    'iniciar y volver no abre; la entrada explícita sigue funcionando con overlay externo',
    (tester) async {
      installNanoAccessDouble();
      // Canal nativo sustituido de forma explícita: simula solo estado/entrada,
      // no dibuja un overlay ni acredita funcionamiento sobre otra aplicación.
      const channel = MethodChannel('dev.nanoai/floating');
      Future<Map<String, Object>>? pendingEntry;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isActive') return true;
            if (call.method == 'takePendingEntry') {
              final next = pendingEntry;
              pendingEntry = null;
              return next;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final audio = ValueNotifier(0.0);
      final actions = NanoTestActions();
      await tester.pumpWidget(
        MaterialApp(
          home: NanoFloatingWrapper(
            webProviders: const [],
            actions: actions,
            audioLevel: audio,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Búho AI'), findsNothing);
      expect(NanoFloatingWrapper.expand(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Búho AI'), findsOneWidget);
      // Minimizar conserva el orbe; la X oculta ambas superficies. No son
      // dos cierres equivalentes ni requieren una pulsación larga oculta.
      await tester.tap(find.byTooltip('Contraer a burbuja'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(NanoFloatingWrapper.activeController!.isVisible, isTrue);
      NanoFloatingWrapper.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip('Cerrar asistente'));
      await tester.pump();
      expect(NanoFloatingWrapper.activeController!.isVisible, isFalse);
      expect(find.text('Búho AI'), findsNothing);
      NanoFloatingWrapper.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // Una ida y vuelta rápida puede no llegar a paused en Android.
      expect(NanoFloatingWrapper.activeController!.isVisible, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Búho AI'), findsNothing);
      expect(NanoFloatingWrapper.activeController!.isVisible, isFalse);
      // Una entrada consumida justo al salir conserva su texto, pero nunca
      // resucita el panel. El usuario aún puede recuperarla al abrir después.
      final lateEntry = Completer<Map<String, Object>>();
      pendingEntry = lateEntry.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      lateEntry.complete({
        'open': true,
        'prompt': 'Borrador tardío',
        'mode': 'quick',
      });
      await tester.pump();
      expect(NanoFloatingWrapper.activeController!.isVisible, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Búho AI'), findsNothing);
      NanoFloatingWrapper.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.widgetWithText(TextField, 'Borrador tardío'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      audio.dispose();
      expect(NanoFloatingWrapper.activeController, isNull);
    },
  );
}
