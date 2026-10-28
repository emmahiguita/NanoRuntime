part of 'agent_tool_dispatcher.dart';

/// [AgentToolExecutionRouter] — Despacho y ejecución de llamadas de herramientas (< 200 líneas).
extension AgentToolExecutionRouter on AgentToolDispatcher {
  /// Propaga el token propietario hasta mensajería; cerrar la UI no basta
  /// para cancelar un intento de envío ya preparado por el mismo run.
  Future<String> _executeTool(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
    if (_dynamicRegistry != null && _dynamicRegistry.supportsTool(call.tool)) {
      return await _dynamicRegistry.dispatchCall(call);
    }

    if (_agentMessagingAliases.contains(call.tool))
      return _executeMessagingTool(call, cancellation: cancellation);
    switch (call.tool) {
      case 'screen':
        return (call.args?['readText'] == true || call.args?['mode'] == 'text')
            ? _uiHandler.readScreenText()
            : _uiHandler.describeScreen();
      case 'read_screen':
        return _uiHandler.readScreenText();
      case 'resolve':
        return (call.selectorArg?.isEmpty ?? true)
            ? '[tool] resolve requiere "selector".'
            : _uiHandler.resolve(call.selectorArg!);
      case 'tap':
        return (call.selectorArg?.isEmpty ?? true)
            ? '[tool] tap requiere "selector".'
            : _uiHandler.tap(call);
      case 'write':
        return (call.selectorArg?.isEmpty ?? true)
            ? '[tool] write requiere "selector".'
            : _uiHandler.write(call);
      case 'back':
        return _uiHandler.back(call);
      case 'home':
        return _uiHandler.navigate(call, 'Pantalla de inicio', 'home');
      case 'recents':
        return _uiHandler.navigate(call, 'Recientes', 'recents');
      case 'open_notifications':
        return _uiHandler.navigate(
          call,
          'Sombra de notificaciones',
          'notifications',
        );
      case 'open_quick_settings':
        return _uiHandler.navigate(call, 'Ajustes rápidos', 'quick_settings');
      case 'swipe':
        return _uiHandler.doSwipe(call);
      case 'scroll':
        return _uiHandler.doScroll(call);
      case 'long_press':
        return _uiHandler.doLongPress(call);
      case 'open_system':
        return _uiHandler.openSystem(call);
      case 'open_url':
        final urlArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (urlArg.isEmpty) return '[tool] open_url requiere <url>.';
        return _webHandler.openUrl(
          urlArg,
          packageName: (call.args?['packageName'] as String?)?.trim(),
        );
      case 'fetch_web' || 'web_fetch' || 'http_get':
        final urlArg =
            (call.textArg ??
                    call.selectorArg ??
                    (call.args?['url'] as String?) ??
                    '')
                .trim();
        if (urlArg.isEmpty) return '[tool] fetch_web requiere <url>.';
        return _webHandler.fetchWeb(urlArg);
      case 'search_knowledge' || 'search_web':
        final q =
            (call.textArg ??
                    call.selectorArg ??
                    (call.args?['query'] as String?) ??
                    '')
                .trim();
        if (q.isEmpty) {
          return '[tool] search_knowledge requiere "query" o texto.';
        }
        return _webHandler.searchKnowledge(q);
      case 'browser_ai_query' || 'reverse_agent_query':
        final provider =
            (call.args?['provider'] as String?)?.trim() ?? 'gemini';
        final prompt =
            (call.args?['prompt'] as String?) ??
            call.textArg ??
            call.selectorArg ??
            '';
        return _browserAgentHandler.executeQuery(
          provider: provider,
          prompt: prompt,
          headless: call.args?['headless'] != false,
        );
      case 'browser.ai.ask' ||
          'browser.ai.providers' ||
          'browser.ai.open' ||
          'browser.ai.get_response' ||
          'browser.ai.list':
        final adapter = _browserAiAdapter;
        if (adapter != null) {
          final outcome = await adapter.execute(call);
          return outcome.feedback;
        }
        return '[error] BrowserAiAdapter no está disponible.';
      case 'launch_app':
        return _handleLaunchApp(call);
      case 'notifications':
        return _notificationHandler.listNotifications();
      case 'device_state':
        return _deviceHandler.deviceState();
      case 'shizuku_query_package':
        final pkgArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (pkgArg.isEmpty) {
          return '[tool] shizuku_query_package requiere <packageName>.';
        }
        return _shizukuHandler.queryPackage(pkgArg);
      case 'force_stop_package':
        final pkgArg2 = (call.textArg ?? call.selectorArg ?? '').trim();
        if (pkgArg2.isEmpty) {
          return '[tool] force_stop_package requiere <packageName>.';
        }
        return _shizukuHandler.forceStop(
          pkgArg2,
          platformStateReader: _platformStateReader,
        );
      case 'install_package':
        final apkArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (apkArg.isEmpty) return '[tool] install_package requiere <apkPath>.';
        return _shizukuHandler.install(apkArg);
      case 'grant_specific_permission':
        final pkgArg3 = (call.textArg ?? call.selectorArg ?? '').trim();
        final permArg = ((call.args?['permission'] as String?) ?? '').trim();
        if (pkgArg3.isEmpty || permArg.isEmpty) return '[tool] grant_specific_permission requiere <packageName> y permission.';
        return _shizukuHandler.grantPermission(pkgArg3, permArg);
      case 'reply_notification':
        return _handleReplyNotification(call);
      case 'dev.inspect_app' || 'inspect_app' || 'inspeccionar':
        return _appInspectorHandler.execute(call);
      case 'dev.diagnostics' || 'diagnostics' || 'diagnostico' || 'diagnóstico':
        return _diagnosticsHandler.execute(call);
      case 'dev.adb' || 'adb':
        return _adbHandler.execute(call);
      case 'dev.run_benchmark' || 'run_benchmark' || 'benchmark':
        return _benchmarkHandler.execute(call);
      case 'linux.list' ||
          'linux.readFile' ||
          'linux.readfile' ||
          'linux.writeFile' ||
          'linux.writefile' ||
          'linux.run':
        return _linuxHandler.executeLinuxTool(call, registry);
      case 'mcp.read' ||
          'mcp.device' ||
          'mcp.externalWrite' ||
          'mcp.privileged':
        return _mcpHandler.executeMcpTool(call);
      default:
        if (call.tool.toLowerCase().startsWith('nano.linux.')) {
          return _semanticLinuxHandler.handleToolCall(call);
        }
        return '[tool] Herramienta desconocida "${call.tool}".';
    }
  }
}
