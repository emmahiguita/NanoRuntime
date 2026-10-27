/// LocalDeviceMcpClient — implementación nativa y en-proceso de McpClientPort.
///
/// Describe y adapta observación, métricas y acciones móviles reales.
/// Sus acciones requieren la autorización del agente; conectar el cliente
/// no demuestra que el servicio de accesibilidad esté disponible.
library;

import 'dart:convert';

import '../../../../core/services/device_metrics.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../execution/agent_executor.dart';
import '../execution/agent_result.dart';
import '../perception/nano_selector.dart';
import '../perception/nano_snapshot.dart';
import '../system/installed_app_catalog.dart';
import 'mcp_client_port.dart';

part 'local_device_observation_schema.dart';
part 'local_device_actions_schema.dart';
part 'local_device_mobile.dart';
part 'local_device_inspection.dart';
part 'local_device_results.dart';

typedef MobileAtomicSnapshotSource =
    Future<Map<dynamic, dynamic>?> Function(bool includeScreenshot);
typedef MobileStatusSource = Future<Map<dynamic, dynamic>?> Function();
typedef MobileGlobalActionSource = Future<bool> Function(String action);
typedef MobileLaunchPackageSource = Future<bool> Function(String packageName);

class LocalDeviceMcpClient implements McpClientPort {
  LocalDeviceMcpClient({
    InstalledAppCatalog? appCatalog,
    AgentExecutor? agentExecutor,
    MobileAtomicSnapshotSource? atomicSnapshotSource,
    MobileStatusSource? statusSource,
    MobileGlobalActionSource? globalActionSource,
    MobileLaunchPackageSource? launchPackageSource,
  }) : _appCatalog = appCatalog,
       _agentExecutor = agentExecutor,
       _atomicSnapshotSource =
           atomicSnapshotSource ??
           ((includeScreenshot) => NanoRuntimeApi.instance
               .agentDumpAtomicSnapshot(includeScreenshot: includeScreenshot)),
       _statusSource = statusSource ?? NanoRuntimeApi.instance.agentStatus,
       _globalActionSource =
           globalActionSource ?? NanoRuntimeApi.instance.agentGlobalAction,
       _launchPackageSource =
           launchPackageSource ?? NanoRuntimeApi.instance.agentLaunchPackage;

  final InstalledAppCatalog? _appCatalog;
  final AgentExecutor? _agentExecutor;
  final MobileAtomicSnapshotSource _atomicSnapshotSource;
  final MobileStatusSource _statusSource;
  final MobileGlobalActionSource _globalActionSource;
  final MobileLaunchPackageSource _launchPackageSource;
  McpConnectionState _state = McpConnectionState.connected;

  @override
  McpServerDescriptor get descriptor => const McpServerDescriptor(
    id: 'device',
    displayName: 'Nano Mobile Agent',
    transport: McpTransportKind.androidBinder,
    metadata: {'version': '2.0.0', 'local': true, 'nanoNative': true},
  );

  @override
  McpConnectionState get state => _state;

  @override
  Future<McpConnectionResult> connect() async {
    _state = McpConnectionState.connected;
    return const McpConnectionResult(
      status: McpOperationStatus.success,
      protocolVersion: '2024-11-05',
      message: 'Local Device MCP Client conectado exitosamente.',
    );
  }

  @override
  Future<void> disconnect() async {
    _state = McpConnectionState.disconnected;
  }

  @override
  Future<List<McpRemoteTool>> listTools() async => [
    ..._observationTools,
    ..._actionsTools,
  ];

  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    final tool = call.toolName.toLowerCase().trim();
    try {
      final result =
          await _mobileCall(call, tool) ?? await _inspectionCall(call, tool);
      if (result != null) return result;
      return McpToolCallResult(
        status: McpOperationStatus.unsupported,
        errorCode: 'TOOL_NOT_FOUND',
        message: 'Herramienta MCP "$tool" no encontrada en servidor "device".',
      );
    } catch (e) {
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'EXECUTION_EXCEPTION',
        message: 'Excepción ejecutando herramienta MCP "$tool": $e',
      );
    }
  }
}
