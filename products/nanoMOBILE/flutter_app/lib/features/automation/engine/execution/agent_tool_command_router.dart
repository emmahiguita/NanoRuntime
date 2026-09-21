part of 'agent_tool_dispatcher.dart';

/// [AgentToolCommandRouter]
///
/// QUÉ HACE:
/// Despacha y procesa los comandos directos del usuario iniciados con el prefijo `@`
/// (por ejemplo: `@pantalla`, `@tap`, `@escribir`, `@whatsapp`, `@bateria`, `@mcp`, etc.).
///
/// CÓMO FUNCIONA:
/// Analiza el verbo principal del comando y sus argumentos, delegando de forma determinista
/// a los handlers especializados correspondientes (UI, Dispositivo, WhatsApp, Linux, Web, MCP).
/// Si el verbo genera una acción que requiere interacción con el sistema, crea el [ToolCall]
/// respectivo con confirmación humana implícita.
///
/// POR QUÉ:
/// Desacopla el enrutamiento de comandos escritos por humanos del núcleo de [AgentToolDispatcher],
/// garantizando que los archivos permanezcan modulares (< 200 líneas) y respetando el principio
/// de responsabilidad única (Single Responsibility Principle).
extension AgentToolCommandRouter on AgentToolDispatcher {
  Future<String> _dispatchCommandVerb(
    String verb,
    String rest, {
    String? executionId,
    ExecutionCancellationToken? cancellation,
  }) async {
    final ToolCall? call;
    switch (verb) {
      case 'pantalla' || 'screen':
        call = const ToolCall(tool: 'screen');
      case 'leer' || 'leer_pantalla':
        return _uiHandler.readScreenText();
      case 'resolver' || 'resolve':
        call = ToolCall(tool: 'resolve', selector: rest);
      case 'tap' || 'tocar':
        call = ToolCall(tool: 'tap', selector: rest);
      case 'escribir' || 'write':
        final sep = rest.lastIndexOf(' | ');
        if (sep < 0) {
          return 'Sintaxis: @escribir <texto> | <selector>. Ej: @escribir wifi | editable=true';
        }
        call = ToolCall(
          tool: 'write',
          text: rest.substring(0, sep).trim(),
          selector: rest.substring(sep + 3).trim(),
        );
      case 'back' || 'atras' || 'atrás':
        call = const ToolCall(tool: 'back');
      case 'notificaciones' || 'notifications':
        call = const ToolCall(tool: 'notifications');
      case 'bateria' || 'battery' || 'dispositivo' || 'device_state' || 'wifi' || 'red':
        return _deviceHandler.deviceState();
      case 'diagnostico' || 'diagnóstico' || 'diagnostics' || 'device.diagnostics' || 'device_diagnostics':
        return _diagnosticsHandler.handleCommand(rest);
      case 'git':
        return (await runToolGuarded(
          ToolCall(
            tool: 'linux.run',
            args: {'command': rest.isEmpty ? 'git status' : 'git $rest'},
          ),
          humanInitiated: true,
          executionId: executionId,
          cancellation: cancellation,
        )).feedback;
      case 'home' || 'inicio':
        call = const ToolCall(tool: 'home');
      case 'recents' || 'recientes':
        call = const ToolCall(tool: 'recents');
      case 'sombra':
        call = const ToolCall(tool: 'open_notifications');
      case 'quick_settings' || 'ajustes_rapidos':
        call = const ToolCall(tool: 'open_quick_settings');
      case 'capacidades' || 'capabilities' || 'resumen':
        return _deviceHandler.runCapabilitiesReport();
      case 'escuchar' || 'voz':
        return _deviceHandler.listenVoice();
      case 'habla':
        return _deviceHandler.speak(rest);
      case 'conceder':
        return _deviceHandler.runGrantPermission(rest);
      case 'conceder_accessibility':
        return _deviceHandler.runGrantPermission('accessibility');
      case 'conceder_notificaciones':
        return _deviceHandler.runGrantPermission('notificaciones');
      case 'conceder_archivos':
        return _deviceHandler.runGrantPermission('archivos');
      case 'conceder_runtime':
        return _deviceHandler.runGrantPermission('runtime');
      case 'conceder_shizuku':
        return _shizukuHandler.grantShizuku();
      case 'responder' || 'reply':
        return _notificationHandler.respond(rest);
      case 'cuenta' || 'mi_cuenta' || 'google_account':
        return _webHandler.getGoogleAccountInfo();
      case 'ip' || 'mi_ip':
        return _webHandler.fetchIp();
      case 'web' || 'fetch':
        return _webHandler.fetchWeb(rest);
      case 'url' || 'navegar':
        final u = rest.trim();
        if (u.isEmpty) return 'Sintaxis: @url <enlace>. Ej: @url https://google.com';
        final full = u.startsWith('http://') || u.startsWith('https://') ? u : 'https://$u';
        return _webHandler.openUrl(full);
      case 'buscar' || 'google' || 'search':
        return _webHandler.searchKnowledge(rest);
      case 'abrir' || 'launch' || 'launch_app':
        return _deviceHandler.handleOpenAppCommand(
          rest,
          runGuarded: runToolGuarded,
          executionId: executionId,
          cancellation: cancellation,
        );
      case 'mcp':
        return _mcpHandler.handleMcpCommand(
          rest,
          runGuarded: runToolGuarded,
          executionId: executionId,
          cancellation: cancellation,
        );
      case 'gemini':
        return _browserAgentHandler.handleCommand(rest.isNotEmpty ? '@gemini $rest' : '@gemini .');
      case 'gpt' || 'chatgpt':
        return _browserAgentHandler.handleCommand(rest.isNotEmpty ? '@chatgpt $rest' : '@chatgpt .');
      case 'deepseek':
        return _browserAgentHandler.handleCommand(rest.isNotEmpty ? '@deepseek $rest' : '@deepseek .');
      case 'claude':
        return _browserAgentHandler.handleCommand(rest.isNotEmpty ? '@claude $rest' : '@claude .');
      case 'browser_ai':
        return _browserAgentHandler.handleCommand(rest.isNotEmpty ? '@browser_ai $rest' : '@browser_ai .');
      case 'whatsapp' || 'wpp':
        return _whatsAppHandler.handleCommand(rest);
      case 'contactos' || 'contacts':
        return _whatsAppHandler.listContacts(ToolCall(tool: 'whatsapp.contacts', args: {'query': rest}));
      case 'alarma' || 'alarm' || 'despertador':
        return _alarmHandler.handleCommand(rest);
      case 'inspeccionar' || 'inspect' || 'inspect_app':
        return _appInspectorHandler.handleCommand(rest);
      case 'adb':
        return _adbHandler.handleCommand(rest);
      case 'benchmark' || 'run_benchmark':
        return _benchmarkHandler.runBenchmark();
      default:
        return 'Comando desconocido "@$verb". Disponibles: @benchmark, @diagnostico, @inspeccionar <app>, @adb [subcomando], @alarma <hora> [días] [msg], @whatsapp <contacto> [msg], @contactos [filtro], @ip, @gemini <prompt>, @gpt <prompt>, @deepseek <prompt>, @claude <prompt>, @browser_ai, @web <url>, @url <enlace>, @buscar <consulta>, @abrir <app>, @mcp <list|call>, @pantalla, @leer_pantalla, @resolver <selector>, @tap <selector>, @escribir <texto> | <selector>, @notificaciones, @responder [indice] <texto>, @back, @home, @recents, @sombra, @quick_settings, @capacidades, @conceder <permiso|shizuku>.';
    }
    return (await runToolGuarded(
      call,
      humanInitiated: true,
      executionId: executionId,
      cancellation: cancellation,
    )).feedback;
  }
}
