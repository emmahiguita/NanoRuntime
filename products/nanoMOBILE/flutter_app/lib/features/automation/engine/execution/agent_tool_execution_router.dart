part of 'agent_tool_dispatcher.dart';

/// [AgentToolExecutionRouter]
///
/// QUÉ HACE:
/// Rutea y ejecuta llamadas de herramientas estructuradas ([ToolCall]) emitidas por el modelo
/// de lenguaje (LLM) o por comandos directos, delegando a los handlers especializados.
///
/// CÓMO FUNCIONA:
/// 1. Consulta primero el [DynamicToolRegistry] si la herramienta fue registrada dinámicamente (Open/Closed - SOLID).
/// 2. Si no es dinámica, despacha al switch central agrupado por dominios funcionales:
///    - Interfaz y Pantalla (UI, Gestos, Accesibilidad)
///    - Navegación e Internet (Web, Fetch, Browser AI)
///    - Aplicaciones y Sistema (Launch App, Device, Shizuku)
///    - Notificaciones y Mensajería (Reply, WhatsApp)
///    - Desarrollador y Terminal (ADB, Diagnóstico, Benchmark, Linux, MCP)
/// 3. Devuelve una respuesta legible en formato texto feedback garantizando degradación elegante.
///
/// POR QUÉ:
/// Desacopla la matriz de ejecución del orquestador principal [AgentToolDispatcher], reduciendo
/// la complejidad ciclomática y manteniendo los archivos por debajo del límite estricto de 200 líneas.
extension AgentToolExecutionRouter on AgentToolDispatcher {
  Future<String> _executeTool(ToolCall call) async {
    // 1. Delegar dinámicamente si hay un IToolHandler registrado (Principio Open/Closed - SOLID)
    if (_dynamicRegistry != null && _dynamicRegistry.supportsTool(call.tool)) {
      return await _dynamicRegistry.dispatchCall(call);
    }

    switch (call.tool) {
      case 'screen':
        if (call.args?['readText'] == true || call.args?['mode'] == 'text') {
          return _uiHandler.readScreenText();
        }
        return _uiHandler.describeScreen();
      case 'read_screen':
        return _uiHandler.readScreenText();
      case 'resolve':
        if (call.selectorArg == null || call.selectorArg!.isEmpty) {
          return '[tool] resolve requiere "selector".';
        }
        return _uiHandler.resolve(call.selectorArg!);
      case 'tap':
        if (call.selectorArg == null || call.selectorArg!.isEmpty) {
          return '[tool] tap requiere "selector".';
        }
        return _uiHandler.tap(call);
      case 'write':
        if (call.selectorArg == null || call.selectorArg!.isEmpty) {
          return '[tool] write requiere "selector".';
        }
        return _uiHandler.write(call);
      case 'back':
        return _uiHandler.back(call);
      case 'home':
        return _uiHandler.navigate(call, 'Pantalla de inicio', 'home');
      case 'recents':
        return _uiHandler.navigate(call, 'Recientes', 'recents');
      case 'open_notifications':
        return _uiHandler.navigate(call, 'Sombra de notificaciones', 'notifications');
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
        final pkgArg = (call.args?['packageName'] as String?)?.trim();
        return _webHandler.openUrl(urlArg, packageName: pkgArg);
      case 'fetch_web' || 'web_fetch' || 'http_get':
        final urlArg = (call.textArg ?? call.selectorArg ?? (call.args?['url'] as String?) ?? '').trim();
        if (urlArg.isEmpty) return '[tool] fetch_web requiere <url>.';
        return _webHandler.fetchWeb(urlArg);
      case 'search_knowledge' || 'search_web':
        final q = (call.textArg ?? call.selectorArg ?? (call.args?['query'] as String?) ?? '').trim();
        if (q.isEmpty) return '[tool] search_knowledge requiere "query" o texto.';
        return _webHandler.searchKnowledge(q);
      case 'browser_ai_query' || 'reverse_agent_query':
        final provider = (call.args?['provider'] as String?)?.trim() ?? 'gemini';
        final prompt = (call.args?['prompt'] as String?) ?? call.textArg ?? call.selectorArg ?? '';
        final headless = call.args?['headless'] != false;
        return _browserAgentHandler.executeQuery(provider: provider, prompt: prompt, headless: headless);
      case 'browser.ai.ask' || 'browser.ai.providers' || 'browser.ai.open' || 'browser.ai.get_response' || 'browser.ai.list':
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
        if (pkgArg.isEmpty) return '[tool] shizuku_query_package requiere <packageName>.';
        return _shizukuHandler.queryPackage(pkgArg);
      case 'force_stop_package':
        final pkgArg2 = (call.textArg ?? call.selectorArg ?? '').trim();
        if (pkgArg2.isEmpty) return '[tool] force_stop_package requiere <packageName>.';
        return _shizukuHandler.forceStop(pkgArg2, platformStateReader: _platformStateReader);
      case 'install_package':
        final apkArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (apkArg.isEmpty) return '[tool] install_package requiere <apkPath>.';
        return _shizukuHandler.install(apkArg);
      case 'grant_specific_permission':
        final pkgArg3 = (call.textArg ?? call.selectorArg ?? '').trim();
        final permArg = ((call.args?['permission'] as String?) ?? '').trim();
        if (pkgArg3.isEmpty || permArg.isEmpty) {
          return '[tool] grant_specific_permission requiere <packageName> y permission.';
        }
        return _shizukuHandler.grantPermission(pkgArg3, permArg);
      case 'reply_notification':
        return _handleReplyNotification(call);
      case 'whatsapp.open_chat' || 'whatsapp_open':
        return _whatsAppHandler.openChat(call);
      case 'whatsapp.send_message' || 'whatsapp_send':
        return _whatsAppHandler.sendMessage(call);
      case 'whatsapp.share_file' || 'whatsapp.send_file' || 'whatsapp_share':
        return _whatsAppHandler.shareFile(call);
      case 'whatsapp.contacts' || 'whatsapp_contacts':
        return _whatsAppHandler.listContacts(call);
      case 'device.set_alarm' || 'set_alarm' || 'alarma' || 'alarm':
        return _alarmHandler.execute(call);
      case 'dev.inspect_app' || 'inspect_app' || 'inspeccionar':
        return _appInspectorHandler.execute(call);
      case 'dev.diagnostics' || 'diagnostics' || 'diagnostico' || 'diagnóstico':
        return _diagnosticsHandler.execute(call);
      case 'dev.adb' || 'adb':
        return _adbHandler.execute(call);
      case 'dev.run_benchmark' || 'run_benchmark' || 'benchmark':
        return _benchmarkHandler.execute(call);
      case 'linux.list' || 'linux.readFile' || 'linux.readfile' || 'linux.writeFile' || 'linux.writefile' || 'linux.run':
        return _linuxHandler.executeLinuxTool(call, registry);
      case 'mcp.read' || 'mcp.device' || 'mcp.externalWrite' || 'mcp.privileged':
        return _mcpHandler.executeMcpTool(call);
      default:
        if (call.tool.toLowerCase().startsWith('nano.linux.')) {
          return _semanticLinuxHandler.handleToolCall(call);
        }
        return '[tool] Herramienta desconocida "${call.tool}".';
    }
  }

  Future<String> _handleLaunchApp(ToolCall call) async {
    var packageName = call.packageNameArg?.trim() ?? '';
    if (packageName.isEmpty) {
      return '[tool] launch_app requiere args {packageName}.';
    }
    if (_installedAppCatalog != null) {
      final match = await _installedAppCatalog.findApp(packageName);
      if (match is AppMatchResolved) {
        packageName = match.app.packageName;
      } else if (match is AppMatchAmbiguous) {
        final candidates = match.candidates.take(3).map((c) => '${c.label} (${c.packageName})').join(', ');
        return '[ambiguousApp] Múltiples aplicaciones coinciden con "$packageName": $candidates.';
      }
    }
    final launched = await _launchPackage(packageName);
    if (!launched) {
      return '[launchFailed] Android no pudo abrir el paquete "$packageName".';
    }
    final expectation = _uiHandler.expectationFor(call).copyWith(expectedPackage: packageName);
    return _uiHandler.verifiedFeedback('Aplicación abierta por Intent: $packageName.', expectation);
  }

  Future<String> _handleReplyNotification(ToolCall call) async {
    final key = call.keyArg?.trim() ?? '';
    final text = call.textArg?.trim() ?? '';
    if (key.isEmpty) return '[tool] reply_notification requiere "key".';
    if (text.isEmpty) return '[tool] reply_notification requiere "text".';
    final rawActionIndex = call.args?['actionIndex'];
    final rawPostTime = call.args?['postTime'];
    return _notificationHandler.replyNotification(
      key: key,
      text: text,
      actionIndex: rawActionIndex is num ? rawActionIndex.toInt() : null,
      remoteInputKey: (call.args?['remoteInputKey'] as String?)?.trim(),
      contextFingerprint: (call.args?['contextFingerprint'] as String?)?.trim(),
      postTime: rawPostTime is num ? rawPostTime.toInt() : null,
    );
  }
}
