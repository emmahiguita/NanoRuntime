import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/native_ui_context.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

/// Doble explícito del canal: comprueba transporte y aislamiento del contrato;
/// no simula ni acredita clics físicos en WhatsApp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NanoRuntimeChannels.agent);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'el contrato acompaña al clic real del API y no queda fuera del alcance',
    () async {
      final calls = <Map>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.arguments as Map);
        return {'ok': false, 'code': 'DOBLE_EXPLICITO'};
      });
      Future<void> click() async {
        await NanoRuntimeApi.instance.agentClickTarget(
          packageName: 'com.whatsapp',
          resourceId: 'menu',
          className: 'Button',
          text: '',
          description: 'Más opciones',
          bounds: [0, 0, 48, 48],
        );
      }

      await NativeUiContext.run({'headerText': 'Chat A'}, () async {
        await Future<void>.delayed(Duration.zero);
        await click();
      });
      await click();
      expect((calls.first['contextGuard'] as Map)['headerText'], 'Chat A');
      expect(calls.last.containsKey('contextGuard'), isFalse);
    },
  );
  test(
    'turnos concurrentes y errores no comparten una identidad global',
    () async {
      final gate = Completer<void>();
      final a = NativeUiContext.run({'headerText': 'A'}, () async {
        await gate.future;
        return NativeUiContext.current!['headerText'];
      });
      final b = await NativeUiContext.run({'headerText': 'B'}, () async {
        gate.complete();
        return NativeUiContext.current!['headerText'];
      });
      expect(await a, 'A');
      expect(b, 'B');
      await expectLater(
        NativeUiContext.run({
          'headerText': 'Error',
        }, () async => throw StateError('doble')),
        throwsStateError,
      );
      expect(NativeUiContext.current, isNull);
    },
  );
}
