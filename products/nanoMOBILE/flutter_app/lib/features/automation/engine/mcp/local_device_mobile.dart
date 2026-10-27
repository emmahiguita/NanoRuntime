part of 'local_device_mcp_client.dart';

/// Ejecuta únicamente operaciones de mobile ya autorizadas por el agente.
extension _LocalDeviceMobile on LocalDeviceMcpClient {
  Future<McpToolCallResult?> _mobileCall(McpToolCall call, String tool) async {
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

    return null;
  }
}
