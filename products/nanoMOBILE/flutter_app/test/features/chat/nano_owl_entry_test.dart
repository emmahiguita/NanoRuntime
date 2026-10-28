import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/chat/nano_everywhere/nano_floating_wrapper.dart';
import 'support/nano_owl_test_ports.dart';

void main() {
  testWidgets(
    'entrada explícita sin texto abre una vez y no se repite al volver',
    (tester) async {
      installNanoAccessDouble();
      // Doble de canal, identificado: verifica el contrato Dart del arranque
      // explícito; el Intent y las ventanas Android se comprueban en dispositivo.
      const channel = MethodChannel('dev.nanoai/floating');
      var pending = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isActive') return false;
            if (call.method == 'takePendingEntry' && pending) {
              pending = false;
              return {'open': true, 'prompt': '', 'mode': 'quick'};
            }
            return null;
          });
      final audio = ValueNotifier(0.0);
      await tester.pumpWidget(
        MaterialApp(
          home: NanoFloatingWrapper(
            webProviders: const [],
            actions: NanoTestActions(),
            audioLevel: audio,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Búho AI'), findsOneWidget);
      NanoFloatingWrapper.hide();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Búho AI'), findsNothing);
      expect(NanoFloatingWrapper.activeController!.isVisible, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      audio.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
