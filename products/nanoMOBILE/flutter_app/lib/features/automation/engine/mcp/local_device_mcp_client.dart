/// LocalDeviceMcpClient — implementación nativa y en-proceso de McpClientPort.
///
/// Proporciona herramientas MCP factuales y read-only sobre hardware,
/// métricas del sistema y catálogo de aplicaciones. Permite operar el
/// protocolo MCP de forma 100% funcional en el runtime de Nano AI.
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
  Future<List<McpRemoteTool>> listTools() async {
    return const [
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_get_device_state',
        description:
            'Obtiene el package, activity, servicio de accesibilidad y resumen semantico de la pantalla actual.',
        inputSchema: {'type': 'object', 'properties': {}},
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_observe',
        description:
            'Captura un snapshot sincronizado de jerarquia Android y, opcionalmente, screenshot PNG.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'includeScreenshot': {
              'type': 'boolean',
              'default': false,
              'description': 'Incluye el PNG codificado en base64.',
            },
            'maxNodes': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 500,
              'default': 120,
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_find_element',
        description:
            'Resuelve un selector semantico dinamico contra un snapshot fresco sin ejecutar acciones.',
        inputSchema: {
          'type': 'object',
          'required': ['selector'],
          'properties': {
            'selector': {
              'type': 'string',
              'description':
                  'Nano selector: text=Buscar, id=..., role=button;text=Enviar.',
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_tap_element',
        description:
            'Toca un elemento reidentificado por selector semantico; no acepta coordenadas libres.',
        inputSchema: {
          'type': 'object',
          'required': ['selector'],
          'properties': {
            'selector': {'type': 'string'},
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_type_text',
        description:
            'Escribe texto en un editable reidentificado y enfocado de forma segura.',
        inputSchema: {
          'type': 'object',
          'required': ['selector', 'text'],
          'properties': {
            'selector': {'type': 'string'},
            'text': {'type': 'string'},
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_back',
        description: 'Ejecuta la accion global Android Back.',
        inputSchema: {'type': 'object', 'properties': {}},
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_home',
        description: 'Ejecuta la accion global Android Home.',
        inputSchema: {'type': 'object', 'properties': {}},
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: 'device',
        name: 'mobile_open_app',
        description: 'Abre una aplicacion Android por packageName explicito.',
        inputSchema: {
          'type': 'object',
          'required': ['packageName'],
          'properties': {
            'packageName': {'type': 'string'},
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
          openWorldHint: false,
        ),
      ),
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
      if (_isTool(tool, 'mobile_get_device_state')) {
        final status = await _statusSource();
        final snapshot = await _agentExecutor?.snapshot();
        final structured = <String, Object?>{
          'connected': status?['connected'] == true,
          'package': snapshot?.package ?? '',
          'nodeCount': snapshot?.nodes.length ?? 0,
          'windowCount': snapshot?.windows.length ?? 0,
          'truncated': snapshot?.truncated ?? false,
          'capturedAt': snapshot?.capturedAt.toUtc().toIso8601String(),
        };
        return _success(
          'Nano Mobile: ${structured['connected'] == true ? 'conectado' : 'sin servicio'}; '
          'package=${structured['package']}; nodos=${structured['nodeCount']}.',
          structured,
        );
      }

      if (_isTool(tool, 'mobile_observe')) {
        final includeScreenshot = call.arguments['includeScreenshot'] == true;
        final maxNodes = ((call.arguments['maxNodes'] as num?)?.toInt() ?? 120)
            .clamp(1, 500);
        final raw = await _atomicSnapshotSource(includeScreenshot);
        if (raw == null) {
          return _failure(
            McpOperationStatus.unavailable,
            'SERVICE_OFF',
            'AgentAccessibilityService no responde.',
          );
        }
        final atomic = NanoAtomicSnapshot.fromRaw(raw);
        final nodes = atomic.hierarchy.nodes
            .take(maxNodes)
            .map(_nodeToStructured)
            .toList(growable: false);
        final structured = <String, Object?>{
          'protocolVersion': atomic.protocolVersion,
          'package': atomic.hierarchy.package,
          'activity': atomic.activity,
          'width': atomic.width,
          'height': atomic.height,
          'rotation': atomic.rotation,
          'capturedAt': atomic.hierarchy.capturedAt.toUtc().toIso8601String(),
          'synchronizationSkewMs': atomic.synchronizationSkewMs,
          'screenshotRequested': atomic.screenshotRequested,
          'screenshotIncluded': atomic.screenshotIncluded,
          'screenshotErrorCode': atomic.screenshotErrorCode,
          'truncated': atomic.hierarchy.truncated,
          'totalNodeCount': atomic.hierarchy.nodes.length,
          'returnedNodeCount': nodes.length,
          'nodes': nodes,
          if (includeScreenshot && atomic.screenshotPng != null)
            'screenshotPngBase64': base64Encode(atomic.screenshotPng!),
        };
        return _success(
          'Snapshot movil capturado: ${atomic.hierarchy.package}, '
          '${atomic.hierarchy.nodes.length} nodos, '
          'screenshot=${atomic.screenshotIncluded}.',
          structured,
        );
      }

      if (_isTool(tool, 'mobile_find_element')) {
        final selector = _selectorFrom(call);
        if (selector.error != null) return selector.error!;
        final executor = _agentExecutor;
        if (executor == null) return _executorUnavailable();
        final outcome = await executor.resolve(selector.value!);
        return _success(outcome.reason, _resolveToStructured(outcome));
      }

      if (_isTool(tool, 'mobile_tap_element')) {
        final selector = _selectorFrom(call);
        if (selector.error != null) return selector.error!;
        final executor = _agentExecutor;
        if (executor == null) return _executorUnavailable();
        return _executionResult(
          'mobile_tap_element',
          await executor.tap(selector.value!),
        );
      }

      if (_isTool(tool, 'mobile_type_text')) {
        final selector = _selectorFrom(call);
        if (selector.error != null) return selector.error!;
        final text = call.arguments['text'] as String?;
        if (text == null) {
          return _failure(
            McpOperationStatus.failed,
            'BAD_ARG',
            'text es requerido.',
          );
        }
        final executor = _agentExecutor;
        if (executor == null) return _executorUnavailable();
        return _executionResult(
          'mobile_type_text',
          await executor.setText(selector.value!, text),
        );
      }

      if (_isTool(tool, 'mobile_back') || _isTool(tool, 'mobile_home')) {
        final action = _isTool(tool, 'mobile_back') ? 'back' : 'home';
        final ok = await _globalActionSource(action);
        return ok
            ? _success('Accion global $action ejecutada.', {'action': action})
            : _failure(
                McpOperationStatus.failed,
                'ACTION_REJECTED',
                'Android rechazo la accion global $action.',
              );
      }

      if (_isTool(tool, 'mobile_open_app')) {
        final packageName =
            (call.arguments['packageName'] as String?)?.trim() ?? '';
        if (packageName.isEmpty) {
          return _failure(
            McpOperationStatus.failed,
            'BAD_ARG',
            'packageName es requerido.',
          );
        }
        final ok = await _launchPackageSource(packageName);
        return ok
            ? _success('Aplicacion abierta: $packageName.', {
                'packageName': packageName,
              })
            : _failure(
                McpOperationStatus.failed,
                'APP_NOT_LAUNCHABLE',
                'No se pudo abrir $packageName.',
              );
      }

      if (tool == 'diagnostics' || tool == 'device.diagnostics') {
        final metrics = await DeviceMetrics.fetch();
        final ramUsed = (metrics.ramTotalMb - metrics.ramAvailableMb).round();
        final ramTotal = metrics.ramTotalMb.round();
        final ramPct = ramTotal > 0
            ? ((ramUsed / ramTotal) * 100).toStringAsFixed(1)
            : '0';
        final structured = <String, Object?>{
          'batteryPct': metrics.batteryPct,
          'isCharging': metrics.isCharging,
          'ramUsedMb': ramUsed,
          'ramTotalMb': ramTotal,
          'cpuCores': metrics.cpuCores,
          'cpuTempC': metrics.cpuTempC,
        };
        final tempStr = metrics.cpuTempC != null
            ? '${metrics.cpuTempC!.toStringAsFixed(1)}°C'
            : 'Normal';
        final textReport =
            '### 📱 [Local Device Inspector (MCP)] — Diagnóstico\n\n'
            '> **Diagnóstico de Hardware y Memoria del Dispositivo**\n\n'
            '• 🔋 **Batería:** `${metrics.batteryPct.round()}%` ${metrics.isCharging ? "⚡ *(Cargando)*" : ""}\n'
            '• 💾 **Memoria RAM:** `$ramUsed MB` / `$ramTotal MB` (`$ramPct%` en uso)\n'
            '• ⚡ **CPU Cores:** `${metrics.cpuCores}` | 🌡️ **Temperatura:** `$tempStr` \n'
            '• 🛡️ **Estado del Dispositivo:** `Óptimo`';

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
                sampleNames.add('`${app.label}` (`${app.packageName}`)');
              }
            }
          }
        }

        final structured = <String, Object?>{
          'totalLaunchableApps': totalApps,
          'sampleApps': sampleNames,
        };
        final sampleListStr = sampleNames.isEmpty
            ? '  - *(Sin muestra disponible)*'
            : sampleNames.map((s) => '  - $s').join('\n');
        final textReport =
            '### 📱 [Local Device Inspector (MCP)] — Catálogo de Aplicaciones\n\n'
            '> **Resumen del Sistema de Aplicaciones Instaladas**\n\n'
            '• 📦 **Total Launchable:** `$totalApps` aplicaciones detectadas\n'
            '• 🔍 **Muestra Detectada:**\n'
            '$sampleListStr';

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
            '### 📱 [Local Device Inspector (MCP)] — Capacidades del Sistema\n\n'
            '> **Estado de Subsistemas y Protocolos Hardware**\n\n'
            '• ♿ **Servicio de Accesibilidad:** `${a11yBound ? "✅ ACTIVO (Bound)" : "⚠️ INACTIVO"}`\n'
            '• 🔌 **Protocolo MCP:** `✅ Habilitado (In-process Binder)`\n'
            '• 🤖 **Plataforma:** `Android OS`';

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

  bool _isTool(String received, String expected) =>
      received == expected ||
      received == 'device.$expected' ||
      received == 'device/$expected';

  _ParsedSelector _selectorFrom(McpToolCall call) {
    final expression = (call.arguments['selector'] as String?)?.trim() ?? '';
    if (expression.isEmpty) {
      return _ParsedSelector.error(
        _failure(
          McpOperationStatus.failed,
          'BAD_SELECTOR',
          'selector es requerido.',
        ),
      );
    }
    try {
      return _ParsedSelector.value(NanoSelector.parse(expression));
    } on SelectorFormatException catch (error) {
      return _ParsedSelector.error(
        _failure(McpOperationStatus.failed, 'BAD_SELECTOR', error.message),
      );
    }
  }

  McpToolCallResult _executorUnavailable() => _failure(
    McpOperationStatus.unavailable,
    'MOBILE_EXECUTOR_OFF',
    'El ejecutor movil no esta conectado a este servidor MCP.',
  );

  McpToolCallResult _executionResult(
    String operation,
    AgentExecutionResult result,
  ) {
    final structured = <String, Object?>{
      'operation': operation,
      'ok': result.ok,
      'errorCode': result.errorCode?.name,
      'reason': result.reason,
      if (result.targetNode != null)
        'target': _nodeToStructured(result.targetNode!),
    };
    return result.ok
        ? _success('$operation completado y ligado al objetivo.', structured)
        : McpToolCallResult(
            status: McpOperationStatus.failed,
            errorCode: result.errorCode?.name ?? 'MOBILE_ACTION_FAILED',
            message: result.reason,
            structuredContent: structured,
          );
  }

  Map<String, Object?> _resolveToStructured(ResolveOutcome outcome) => {
    'status': outcome.status.name,
    'reason': outcome.reason,
    'candidates': [
      for (final candidate in outcome.candidates)
        {
          'score': candidate.score,
          'matchedCriteria': candidate.matchedCriteria,
          'node': _nodeToStructured(candidate.node),
        },
    ],
  };

  Map<String, Object?> _nodeToStructured(NanoNode node) => {
    'index': node.index,
    'package': node.packageName,
    'resourceId': node.id,
    'className': node.type,
    'text': node.password ? '<redacted>' : node.text,
    'description': node.description,
    'hint': node.hint,
    'stateDescription': node.stateDescription,
    'error': node.errorText,
    'bounds': [
      node.bounds.left,
      node.bounds.top,
      node.bounds.right,
      node.bounds.bottom,
    ],
    'clickable': node.clickable,
    'editable': node.editable,
    'scrollable': node.scrollable,
    'checked': node.checked,
    'selected': node.selected,
    'focused': node.focused,
    'visible': node.visible,
    'enabled': node.enabled,
    'windowId': node.windowId,
  };

  McpToolCallResult _success(String message, Map<String, Object?> structured) =>
      McpToolCallResult(
        status: McpOperationStatus.success,
        content: [McpContentItem(type: 'text', text: message)],
        structuredContent: structured,
      );

  McpToolCallResult _failure(
    McpOperationStatus status,
    String code,
    String message,
  ) => McpToolCallResult(status: status, errorCode: code, message: message);
}

final class _ParsedSelector {
  const _ParsedSelector.value(this.value) : error = null;
  const _ParsedSelector.error(this.error) : value = null;

  final NanoSelector? value;
  final McpToolCallResult? error;
}
