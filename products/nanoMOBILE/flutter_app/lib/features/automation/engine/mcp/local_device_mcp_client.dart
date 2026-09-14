/// LocalDeviceMcpClient — implementación nativa y en-proceso de McpClientPort.
///
/// Proporciona herramientas MCP factuales y read-only sobre hardware,
/// métricas del sistema y catálogo de aplicaciones. Permite operar el
/// protocolo MCP de forma 100% funcional en el runtime de Nano AI.
library;

import '../../../../core/services/device_metrics.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../system/installed_app_catalog.dart';
import 'mcp_client_port.dart';

class LocalDeviceMcpClient implements McpClientPort {
  LocalDeviceMcpClient({InstalledAppCatalog? appCatalog})
    : _appCatalog = appCatalog;

  final InstalledAppCatalog? _appCatalog;
  McpConnectionState _state = McpConnectionState.connected;

  @override
  McpServerDescriptor get descriptor => const McpServerDescriptor(
    id: 'device',
    displayName: 'Local Device Inspector (Nano AI)',
    transport: McpTransportKind.androidBinder,
    metadata: {'version': '1.0.0', 'local': true},
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
  Future<List<McpRemoteTool>> listTools() async {
    return const [
      McpRemoteTool(
        serverId: 'device',
        name: 'diagnostics',
        description:
            'Consulta el estado de salud físico, batería y memoria del dispositivo.',
        inputSchema: {'type': 'object', 'properties': {}},
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'app_summary',
        description:
            'Consulta el recuento y resumen del catálogo de aplicaciones instaladas.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'filter': {
              'type': 'string',
              'description': 'Filtro opcional por nombre o paquete',
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'system_features',
        description:
            'Consulta capacidades de hardware y subsistemas del dispositivo.',
        inputSchema: {'type': 'object', 'properties': {}},
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
        ),
      ),
    ];
  }

  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    final tool = call.toolName.toLowerCase().trim();
    try {
      if (tool == 'diagnostics' || tool == 'device.diagnostics') {
        final metrics = await DeviceMetrics.fetch();
        final ramUsed = (metrics.ramTotalMb - metrics.ramAvailableMb).round();
        final structured = <String, Object?>{
          'batteryPct': metrics.batteryPct,
          'isCharging': metrics.isCharging,
          'ramUsedMb': ramUsed,
          'ramTotalMb': metrics.ramTotalMb.round(),
          'cpuCores': metrics.cpuCores,
          'cpuTempC': metrics.cpuTempC,
        };
        final textReport =
            'Estado del dispositivo:\n'
            '• Batería: ${metrics.batteryPct.round()}% ${metrics.isCharging ? "(Cargando)" : ""}\n'
            '• RAM: $ramUsed MB / ${metrics.ramTotalMb.round()} MB\n'
            '• CPU Cores: ${metrics.cpuCores}\n'
            '• Temperatura: ${metrics.cpuTempC != null ? "${metrics.cpuTempC!.toStringAsFixed(1)}°C" : "N/A"}';

        return McpToolCallResult(
          status: McpOperationStatus.success,
          content: [McpContentItem(type: 'text', text: textReport)],
          structuredContent: structured,
        );
      }

      if (tool == 'app_summary' || tool == 'device.app_summary') {
        int totalApps = 0;
        final sampleNames = <String>[];
        if (_appCatalog != null) {
          final apps = await _appCatalog.refresh();
          totalApps = apps.length;
          final filter = (call.arguments['filter'] as String?)?.toLowerCase();
          for (final app in apps) {
            if (filter == null ||
                app.label.toLowerCase().contains(filter) ||
                app.packageName.toLowerCase().contains(filter)) {
              if (sampleNames.length < 8) {
                sampleNames.add('${app.label} (${app.packageName})');
              }
            }
          }
        }

        final structured = <String, Object?>{
          'totalLaunchableApps': totalApps,
          'sampleApps': sampleNames,
        };
        final textReport =
            'Resumen de aplicaciones instaladas:\n'
            '• Total launchable detectadas: $totalApps\n'
            '• Muestra: ${sampleNames.isEmpty ? "ninguna" : sampleNames.join(", ")}';

        return McpToolCallResult(
          status: McpOperationStatus.success,
          content: [McpContentItem(type: 'text', text: textReport)],
          structuredContent: structured,
        );
      }

      if (tool == 'system_features' || tool == 'device.system_features') {
        final a11yStatus = await NanoRuntimeApi.instance.agentStatus();
        final a11yBound =
            a11yStatus?['connected'] == true || a11yStatus?['enabled'] == true;
        final structured = <String, Object?>{
          'accessibilityServiceActive': a11yBound,
          'platform': 'Android',
          'mcpSupport': 'McpClientPort 2024-11-05',
        };
        final textReport =
            'Capacidades del sistema:\n'
            '• Servicio de Accesibilidad: ${a11yBound ? "ACTIVO (Bound)" : "INACTIVO"}\n'
            '• Soporte MCP: Habilitado (In-process Binder)\n'
            '• Plataforma: Android OS';

        return McpToolCallResult(
          status: McpOperationStatus.success,
          content: [McpContentItem(type: 'text', text: textReport)],
          structuredContent: structured,
        );
      }

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
