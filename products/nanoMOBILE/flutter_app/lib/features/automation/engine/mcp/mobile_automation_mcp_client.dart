/// MobileAutomationMcpClient — Servidor MCP nativo para control móvil de Nano
///
/// Principio de Inversión de Dependencias (DIP) y Responsabilidad Única (SRP):
/// Implementa [McpClientPort] con handshake real de conectividad,
/// delegando contratos a [MobileAutomationToolCatalog] y ejecución verificada a [MobileAutomationExecutor].
library;

import '../../../../core/services/nano_runtime_api.dart';
import '../execution/action_verifier.dart';
import '../execution/agent_executor.dart';
import '../memory/nano_transcript_ledger.dart';
import '../perception/composite_locator.dart';
import 'mcp_client_port.dart';
import 'mobile_automation_executor.dart';
import 'mobile_automation_tool_catalog.dart';

class MobileAutomationMcpClient implements McpClientPort {
  MobileAutomationMcpClient({
    NanoRuntimeApi? api,
    AgentExecutor? executor,
    AgentVerifier? verifier,
    NanoTranscriptLedger? ledger,
    NanoCompositeLocator? locator,
    MobileAutomationExecutor? automationExecutor,
  })  : _api = api ?? NanoRuntimeApi.instance,
        _executor = automationExecutor ??
            MobileAutomationExecutor(
              api: api ?? NanoRuntimeApi.instance,
              executor: executor ?? NanoAgentExecutor(api: api ?? NanoRuntimeApi.instance),
              verifier: verifier ??
                  ActionVerifier(
                    snapshotFn: (executor ?? NanoAgentExecutor(api: api ?? NanoRuntimeApi.instance)).snapshot,
                  ),
              ledger: ledger ?? NanoTranscriptLedger(),
              locator: locator ?? NanoCompositeLocator(),
            );

  final NanoRuntimeApi _api;
  final MobileAutomationExecutor _executor;
  McpConnectionState _state = McpConnectionState.disconnected;

  @override
  McpServerDescriptor get descriptor => const McpServerDescriptor(
        id: MobileAutomationToolCatalog.serverId,
        displayName: 'Nano Mobile Automation Engine',
        transport: McpTransportKind.androidBinder,
        metadata: {
          'version': '2.1.0',
          'engine': 'NanoMobileEngine',
          'architecture': 'Nano-Native',
        },
      );

  @override
  McpConnectionState get state => _state;

  @override
  Future<McpConnectionResult> connect() async {
    _state = McpConnectionState.connecting;

    // 1. Handshake real con el AccessibilityService y Binder
    final status = await _api.agentStatus();
    final connected = status != null && status['connected'] == true;

    if (!connected) {
      _state = McpConnectionState.failed;
      return const McpConnectionResult(
        status: McpOperationStatus.unavailable,
        message: 'AgentAccessibilityService no conectado. Habilitar en Ajustes -> Accesibilidad.',
        metadata: {'binderActive': false},
      );
    }

    // 2. Smoke test de lectura de snapshot para validar reactividad
    final smokeSnap = await _executor.smokeTestSnapshot();
    if (smokeSnap == null || smokeSnap.isEmpty) {
      _state = McpConnectionState.connected;
      return const McpConnectionResult(
        status: McpOperationStatus.success,
        protocolVersion: '2024-11-05',
        message: 'Servicio conectado (ventana activa en espera de settle / rebind).',
        metadata: {'binderActive': true, 'degraded': true},
      );
    }

    _state = McpConnectionState.connected;
    return McpConnectionResult(
      status: McpOperationStatus.success,
      protocolVersion: '2024-11-05',
      message: 'Nano Mobile Automation MCP conectado exitosamente.',
      metadata: {
        'binderActive': true,
        'package': smokeSnap.package,
        'nodes': smokeSnap.nodes.length,
        'degraded': false,
      },
    );
  }

  @override
  Future<void> disconnect() async {
    _state = McpConnectionState.disconnected;
  }

  @override
  Future<List<McpRemoteTool>> listTools() async =>
      MobileAutomationToolCatalog.createToolDefinitions();

  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    final tool = call.toolName.toLowerCase().replaceFirst('nano.mobile.', '').trim();

    try {
      return switch (tool) {
        'observe' => await _executor.observe(call.arguments),
        'tap' => await _executor.tap(call.arguments),
        'type' => await _executor.type(call.arguments),
        'swipe' => await _executor.swipe(call.arguments),
        'press_key' => await _executor.pressKey(call.arguments),
        'launch_app' => await _executor.launchApp(call.arguments),
        'verify' => await _executor.verify(call.arguments),
        'get_ledger_history' => _executor.getLedgerHistory(),
        _ => McpToolCallResult(
            status: McpOperationStatus.unsupported,
            message: 'Herramienta móvil desconocida: ${call.toolName}',
          ),
      };
    } catch (e) {
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'EXECUTION_EXCEPTION',
        message: 'Excepción al ejecutar ${call.toolName}: $e',
      );
    }
  }
}
