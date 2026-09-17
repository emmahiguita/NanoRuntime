import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/automation/engine/execution/action_verifier.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_result.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/mcp_tool_handler.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';
import 'package:nanoai/features/automation/engine/execution/tool_outcome.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/mcp/local_device_mcp_client.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_connection_registry.dart';
import 'package:nanoai/features/automation/engine/mcp/mobile_automation_mcp_client.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

void main() {
  const node = NanoNode(
    index: 0,
    depth: 0,
    packageName: 'com.example',
    id: 'com.example:id/send',
    type: 'android.widget.Button',
    text: 'Enviar',
    description: 'Enviar mensaje',
    clickable: true,
    editable: false,
    scrollable: false,
    checked: false,
    focusable: true,
    focused: false,
    visible: true,
    enabled: true,
    bounds: NanoBounds(left: 10, top: 20, right: 110, bottom: 80),
  );

  test('parsea snapshot atomico y semantica Android enriquecida', () {
    final atomic = NanoAtomicSnapshot.fromRaw({
      'protocolVersion': 1,
      'package': 'com.example',
      'activity': 'com.example.MainActivity',
      'capturedAtEpochMs': 1700000000000,
      'width': 1080,
      'height': 2400,
      'rotation': 0,
      'synchronizationSkewMs': 7.5,
      'screenshotRequested': true,
      'screenshotIncluded': true,
      'screenshotErrorCode': 0,
      'screenshotPng': Uint8List.fromList([137, 80, 78, 71]),
      'nodes': [
        {
          'package': 'com.example',
          'id': 'com.example:id/email',
          'type': 'android.widget.EditText',
          'text': '',
          'desc': '',
          'bounds': [0, 0, 400, 100],
          'visible': true,
          'enabled': true,
          'editable': true,
          'checkable': false,
          'longClickable': true,
          'password': true,
          'drawingOrder': 3,
          'hint': 'Correo',
          'error': 'Formato invalido',
          'heading': false,
          'screenReaderFocusable': true,
          'paneTitle': 'Login',
          'tooltip': 'Introduce tu correo',
          'stateDescription': 'Campo obligatorio',
        },
      ],
    });

    expect(atomic.protocolVersion, 1);
    expect(atomic.screenshotPng, Uint8List.fromList([137, 80, 78, 71]));
    expect(atomic.synchronizationSkewMs, 7.5);
    final parsed = atomic.hierarchy.nodes.single;
    expect(parsed.password, isTrue);
    expect(parsed.hint, 'Correo');
    expect(parsed.errorText, 'Formato invalido');
    expect(parsed.stateDescription, 'Campo obligatorio');
    expect(parsed.screenReaderFocusable, isTrue);
  });

  test('MCP movil ejecuta tap mediante selector dinamico', () async {
    final executor = _FakeExecutor(node);
    final client = LocalDeviceMcpClient(agentExecutor: executor);

    final result = await client.callTool(
      const McpToolCall(
        serverId: 'device',
        toolName: 'mobile_tap_element',
        arguments: {'selector': 'text=Enviar'},
      ),
    );

    expect(result.status, McpOperationStatus.success);
    expect(executor.lastTapped?.text, 'Enviar');
    expect(result.structuredContent?['ok'], isTrue);
  });

  test(
    'nano.mobile.tap reidentifica el nodo y no usa coordenadas crudas',
    () async {
      final executor = _FakeExecutor(node);
      final api = _FakeRuntimeApi();
      final client = MobileAutomationMcpClient(
        api: api,
        executor: executor,
        verifier: const _VerifiedAgentVerifier(),
      );

      final result = await client.callTool(
        const McpToolCall(
          serverId: 'nano.mobile',
          toolName: 'tap',
          arguments: {'text': 'Enviar'},
        ),
      );

      expect(result.status, McpOperationStatus.success);
      expect(executor.lastTapped?.text, 'Enviar');
      expect(api.rawTapCalls, 0);
      expect(result.structuredContent?['verificationOk'], isTrue);
    },
  );

  test('observacion MCP redacta texto de nodos password', () async {
    final client = LocalDeviceMcpClient(
      atomicSnapshotSource: (_) async => {
        'protocolVersion': 1,
        'package': 'com.example',
        'nodes': [
          {
            'package': 'com.example',
            'id': 'password',
            'type': 'android.widget.EditText',
            'text': 'secreto',
            'desc': '',
            'bounds': [0, 0, 100, 40],
            'visible': true,
            'enabled': true,
            'editable': true,
            'password': true,
          },
        ],
      },
    );

    final result = await client.callTool(
      const McpToolCall(serverId: 'device', toolName: 'mobile_observe'),
    );
    final nodes = result.structuredContent?['nodes'] as List<Object?>;
    final first = nodes.single as Map<String, Object?>;

    expect(result.status, McpOperationStatus.success);
    expect(first['text'], '<redacted>');
  });

  test(
    'comando MCP clasifica acciones como externalWrite y lecturas como read',
    () async {
      final registry = McpConnectionRegistry();
      final executor = _FakeExecutor(node);
      await registry.register(LocalDeviceMcpClient(agentExecutor: executor));
      await registry.register(MobileAutomationMcpClient(executor: executor));
      final handler = McpToolHandler(mcpConnectionRegistry: registry);

      final captured = <ToolCall>[];
      Future<ToolOutcome> guarded(
        ToolCall call, {
        bool humanInitiated = false,
        String? executionId,
        dynamic cancellation,
      }) async {
        captured.add(call);
        return const ToolOutcome(
          verdict: PolicyVerdict.allow,
          feedback: 'ok',
          executionStatus: ToolExecutionStatus.completed,
        );
      }

      await handler.handleMcpCommand(
        'call device.mobile_observe',
        runGuarded: guarded,
      );
      await handler.handleMcpCommand(
        'call device.mobile_tap_element {"selector":"text=Enviar"}',
        runGuarded: guarded,
      );
      await handler.handleMcpCommand(
        'call nano.mobile.observe',
        runGuarded: guarded,
      );
      await handler.handleMcpCommand(
        'call nano.mobile.tap {"text":"Enviar"}',
        runGuarded: guarded,
      );

      expect(captured[0].tool, 'mcp.read');
      expect(captured[1].tool, 'mcp.externalWrite');
      expect(captured[2].tool, 'mcp.read');
      expect(captured[3].tool, 'mcp.externalWrite');

      final dottedResult = await handler.executeMcpTool(
        const ToolCall(
          tool: 'mcp.read',
          args: {'mcpTool': 'nano.mobile.get_ledger_history'},
        ),
      );
      expect(dottedResult, contains('"totalSteps":0'));
    },
  );
}

final class _FakeExecutor implements AgentExecutor {
  _FakeExecutor(this.node);

  final NanoNode node;
  NanoSelector? lastTapped;

  ResolveOutcome get _resolved => ResolveOutcome(
    status: ResolveStatus.resolved,
    candidates: [
      ScoreEntry(node: node, score: 100, matchedCriteria: const ['text']),
    ],
    reason: 'Objetivo resuelto.',
  );

  @override
  Future<ResolveOutcome> resolve(NanoSelector selector) async => _resolved;

  @override
  Future<NanoSnapshot?> snapshot() async =>
      NanoSnapshot(package: node.packageName, nodes: [node]);

  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async {
    lastTapped = selector;
    return AgentExecutionResult.ok(resolve: _resolved, targetNode: node);
  }

  @override
  Future<AgentExecutionResult> setText(
    NanoSelector selector,
    String text,
  ) async => AgentExecutionResult.ok(resolve: _resolved, targetNode: node);
}

final class _FakeRuntimeApi extends NanoRuntimeApi {
  _FakeRuntimeApi();

  int rawTapCalls = 0;

  @override
  Future<bool> agentTapAt(int x, int y) async {
    rawTapCalls++;
    return true;
  }
}

final class _VerifiedAgentVerifier implements AgentVerifier {
  const _VerifiedAgentVerifier();

  @override
  Future<VerificationOutcome> verify(
    ActionExpectation expectation, {
    NanoSnapshot? preSnapshot,
  }) async => const VerificationOutcome(
    status: VerificationStatus.verified,
    reason: 'Postcondición satisfecha.',
  );
}
