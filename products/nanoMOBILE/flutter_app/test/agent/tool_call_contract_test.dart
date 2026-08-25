import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';

/// Contrato tipado de ToolCall (A4): `args` es la vía canónica; `selector`/
/// `text`/`key` son aliases legacy leídos vía getters tipados. Los getters dan
/// precedencia a `args` y caen al campo legacy solo si args no trae la clave.
void main() {
  test('selectorArg: args.selector tiene precedencia sobre legacy', () {
    const a = ToolCall(tool: 'tap', args: {'selector': 'text=Bluetooth'});
    expect(a.selectorArg, 'text=Bluetooth');

    const b = ToolCall(tool: 'tap', selector: 'text=Bluetooth');
    expect(b.selectorArg, 'text=Bluetooth');

    const c = ToolCall(
      tool: 'tap',
      selector: 'legacy',
      args: {'selector': 'args'},
    );
    expect(c.selectorArg, 'args');
  });

  test('textArg/keyArg: args primero, fallback legacy', () {
    const a = ToolCall(tool: 'write', args: {'text': 'hola'});
    expect(a.textArg, 'hola');

    const b = ToolCall(tool: 'write', text: 'hola');
    expect(b.textArg, 'hola');

    const c = ToolCall(tool: 'reply_notification', key: 'k', text: 'hola');
    expect(c.keyArg, 'k');
    expect(c.textArg, 'hola');
  });

  test('packageNameArg: args.packageName o selector legacy', () {
    const a = ToolCall(
      tool: 'launch_app',
      args: {'packageName': 'com.android.chrome'},
    );
    expect(a.packageNameArg, 'com.android.chrome');

    const b = ToolCall(tool: 'launch_app', selector: 'com.android.chrome');
    expect(b.packageNameArg, 'com.android.chrome');
  });

  test('destinationArg: solo args.destination', () {
    const a = ToolCall(
      tool: 'open_system',
      args: {'destination': 'bluetooth_settings'},
    );
    expect(a.destinationArg, 'bluetooth_settings');

    const b = ToolCall(tool: 'open_system');
    expect(b.destinationArg, isNull);
  });

  test('getters null-safe sin args ni legacy', () {
    const a = ToolCall(tool: 'back');
    expect(a.selectorArg, isNull);
    expect(a.textArg, isNull);
    expect(a.keyArg, isNull);
    expect(a.packageNameArg, isNull);
  });
}
