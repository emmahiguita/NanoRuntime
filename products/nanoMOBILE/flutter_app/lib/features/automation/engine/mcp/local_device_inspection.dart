part of 'local_device_mcp_client.dart';

/// Ejecuta únicamente operaciones de inspection ya autorizadas por el agente.
extension _LocalDeviceInspection on LocalDeviceMcpClient {
  Future<McpToolCallResult?> _inspectionCall(
    McpToolCall call,
    String tool,
  ) async {
    if (tool == 'diagnostics' || tool == 'device.diagnostics') {
      final metrics = await DeviceMetrics.fetch();
      final ramUsed = (metrics.ramTotalMb - metrics.ramAvailableMb).round();
      final ramTotal = metrics.ramTotalMb.round();
      final ramPct = ramTotal > 0
          ? ((ramUsed / ramTotal) * 100).toStringAsFixed(1)
          : 'no disponible';
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
          : 'No disponible';
      final textReport =
          '### 📱 [Local Device Inspector (MCP)] — Diagnóstico\n\n'
          '> **Diagnóstico de Hardware y Memoria del Dispositivo**\n\n'
          '• 🔋 **Batería:** `${metrics.batteryPct.round()}%` ${metrics.isCharging ? "⚡ *(Cargando)*" : ""}\n'
          '• 💾 **Memoria RAM:** `$ramUsed MB` / `$ramTotal MB` (`$ramPct%` en uso)\n'
          '• ⚡ **CPU Cores:** `${metrics.cpuCores}` | 🌡️ **Temperatura:** `$tempStr` \n'
          '• **Evaluación global:** no realizada; solo se muestran métricas medidas.';

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

    return null;
  }
}
