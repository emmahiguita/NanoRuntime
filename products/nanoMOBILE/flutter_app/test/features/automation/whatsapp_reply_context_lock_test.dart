import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/whatsapp_reply_context.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/whatsapp_reply_context_lock.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';
import 'package:nanoai/features/automation/engine/execution/tool_outcome.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/notification_tool_handler.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

/// Fixture del recorrido observado: una cabecera y entry en la misma ventana.
NanoNode node(String id, {String text = '', bool editable = false}) => NanoNode(
  index: editable ? 1 : 0,
  depth: 1,
  packageName: 'com.whatsapp',
  windowId: 1583,
  rootIdentity: 'root',
  id: 'com.whatsapp:id/$id',
  type: editable ? 'android.widget.EditText' : 'android.widget.TextView',
  text: text,
  description: '',
  clickable: false,
  editable: editable,
  scrollable: false,
  checked: false,
  focusable: editable,
  focused: editable,
  visible: true,
  enabled: true,
  bounds: NanoBounds(
    left: 0,
    top: editable ? 900 : 100,
    right: 1080,
    bottom: editable ? 1000 : 200,
  ),
);

/// Mantiene el paquete y foco reales sin invocar canales ni abrir aplicaciones.
NanoSnapshot snapshot({
  String title = 'Mi número',
  bool duplicateHeader = false,
  int window = 1583,
  bool truncated = false,
}) => NanoSnapshot(
  package: 'com.whatsapp',
  truncated: truncated,
  nodes: [
    node('conversation_contact_name', text: title),
    if (duplicateHeader) node('conversation_contact_name', text: title),
    node('entry', editable: true),
  ],
  windows: [
    NanoWindow(
      windowId: window,
      windowType: 1,
      displayId: 0,
      packageName: 'com.whatsapp',
      rootIdentity: 'root',
      active: true,
      focused: true,
    ),
  ],
);

/// Liga el consentimiento al snapshot inicial, no al título de una agenda.
ToolCall callFor(NanoSnapshot source) => ToolCall(
  tool: 'whatsapp.send_message',
  args: {
    'replyInPlace': true,
    'contact': 'Mi número',
    'text': 'PRUEBA NANO',
    'packageName': 'com.whatsapp',
    'windowId': 1583,
    'rootIdentity': 'root',
    'contextFingerprint': WhatsAppReplyContext.fingerprint(
      source,
      1583,
      'root',
    ),
  },
);

/// Solo entrega la ventana observada; cualquier gesto en el gate falla la prueba.
class ObservedExecutor implements AgentExecutor {
  ObservedExecutor(this.observed);
  final NanoSnapshot observed;
  int calls = 0;
  @override
  Future<NanoSnapshot?> snapshot() async {
    calls++;
    return observed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('El gate no debe ejecutar gestos');
}

void main() {
  test(
    'el gate de producción dirige la respuesta visible al validador WhatsApp',
    () async {
      final observed = snapshot();
      final executor = ObservedExecutor(observed);
      final gate = NotificationToolHandler(executor: executor);
      expect(
        await gate.validateContextLock(
          callFor(observed),
          ToolRegistry.builtin.lookup('whatsapp.send_message')!,
        ),
        isNull,
      );
      expect(executor.calls, 1);
    },
  );
  test(
    'el envío observado sigue exigiendo context lock y tiene validador real',
    () {
      final snap = snapshot();
      expect(
        ToolRegistry.builtin
            .lookup('whatsapp.send_message')!
            .requiresContextLock,
        isTrue,
      );
      expect(validateWhatsAppReplyContext(callFor(snap), snap), isNull);
    },
  );
  test(
    'cambio de destinatario, ventana o lectura parcial bloquea antes de escribir',
    () {
      final call = callFor(snapshot());
      for (final changed in [
        snapshot(title: 'Otro chat'),
        snapshot(window: 99),
        snapshot(truncated: true),
        snapshot(duplicateHeader: true),
      ]) {
        expect(
          validateWhatsAppReplyContext(call, changed)?.executionStatus,
          ToolExecutionStatus.notExecuted,
        );
      }
    },
  );
  test('una bandera sin identidad no elude el contexto', () {
    final call = ToolCall(
      tool: 'whatsapp.send_message',
      args: {
        'replyInPlace': true,
        'contact': 'Mi número',
        'text': 'PRUEBA NANO',
      },
    );
    expect(
      validateWhatsAppReplyContext(call, snapshot())?.verdict,
      PolicyVerdict.denied,
    );
    expect(
      validateWhatsAppReplyContext(callFor(snapshot()), null)?.verdict,
      PolicyVerdict.denied,
    );
  });
}
