import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../agent/agent_tool_dispatcher.dart';
import '../services/device_info.dart';
import '../services/llm_engine_client.dart';
import '../services/runtime_engine.dart';
import '../models/chat_models.dart';
import '../models/catalog_models.dart';
import 'settings_provider.dart';

// ================================================================
// Chat State and Notifier
// ================================================================

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  // Interfaz de inferencia del motor: propiedad de RuntimeEngineNotifier
  // (único dueño del ciclo de vida). Nadie crea LLMEngineClient directo.
  LLMEngineClient get _engine =>
      _ref.read(runtimeEngineProvider.notifier).client;
  // Cliente HTTP de la generación streaming en curso. Se cierra para cancelar.
  http.Client? _streamClient;
  // Cancelación cooperativa: STOP o un segundo envío anulan la generación en curso.
  bool _generationCancelled = false;
  // Timer de carga de modelo: cancelable para que solo el último
  // modelo seleccionado pueda transicionar a ready.
  Timer? _loadTimer;
  // Flush periódico del texto streaming: agrupa tokens (~32ms) para evitar
  // un rebuild de la lista de mensajes por cada token del motor.
  Timer? _flushTimer;
  String _sessionId = _newSessionId();

  static String _newSessionId() =>
      'chat-${DateTime.now().microsecondsSinceEpoch}';

  /// Tiempo maximo sin tokens antes de abortar el stream como fallo real.
  static const Duration _streamIdleTimeout = Duration(seconds: 45);

  /// Ventana de historial conversacional inteligente multi-turno.
  static const int _maxHistoryMessages = 10;
  static const int _maxHistoryChars = 1200;
  static const int _maxUserChars = 2000;
  static const int _maxAttachmentChars = 1500;
  static const int _maxToolTraceChars = 900;

  /// Máximo de rondas de herramienta por mensaje del usuario: evita bucles
  /// infinitos si el modelo insiste en llamar tools sin concluir.
  static const int _maxToolRounds = 2;

  /// Genera un system prompt dinámico con contexto en tiempo real
  /// y telemetría 100% real del hardware (sin simulación).
  String _buildSystemPrompt() {
    final now = DateTime.now();
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final dayName = weekdays[(now.weekday - 1).clamp(0, 6)];
    final monthName = months[(now.month - 1).clamp(0, 11)];
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final dateStr = '$dayName, ${now.day} de $monthName de ${now.year}';
    final modelName = state.activeModel;

    final info = DeviceInfo.read();
    final buffer = StringBuffer();
    buffer.writeln('Eres NanoAI, un asistente de inteligencia artificial avanzado y soberano ');
    buffer.writeln('que se ejecuta localmente en el dispositivo móvil del usuario mediante el motor nanortime (llama.cpp). ');
    buffer.writeln('Modelo activo actual: "$modelName". ');
    buffer.writeln('Responde siempre en español (o en el idioma en que el usuario te hable) ');
    buffer.writeln('de forma natural, completa, estructurada y útil como cualquier asistente conversacional. ');
    buffer.writeln('Puedes organizar información con formato Markdown rico, tablas claras, listas y diagramas (en bloques de código ```mermaid o esquemas ASCII). ');
    buffer.writeln('Tus respuestas pueden ser exportadas directamente a informes PDF profesionales por el usuario. ');
    buffer.writeln('Si necesitas una herramienta del sistema, responde solo JSON: ');
    buffer.writeln('{"tool":"screen"}, {"tool":"tap","selector":"<sel>"}, ');
    buffer.writeln('{"tool":"write","selector":"<sel>","text":"..."}, {"tool":"back"}. ');
    buffer.writeln('Si no usas herramienta, responde normal con texto.');
    
    buffer.writeln('<realtime_context>');
    buffer.writeln('  <datetime>$dateStr, $timeStr</datetime>');
    if (info.cpuHardware != null && info.cpuHardware!.isNotEmpty) {
      buffer.writeln('  <cpu>${info.cpuHardware} (${info.cpuCores ?? 8} núcleos, ${info.unameMachine ?? "arm64"})</cpu>');
    }
    if (info.memTotalKb != null && info.memAvailKb != null && info.memTotalKb! > 0) {
      final totalGb = (info.memTotalKb! / (1024 * 1024)).toStringAsFixed(1);
      final freeGb = (info.memAvailKb! / (1024 * 1024)).toStringAsFixed(1);
      buffer.writeln('  <ram>libres: $freeGb GB, total: $totalGb GB</ram>');
    }
    if (info.cpuTempC != null && info.cpuTempC! > 0) {
      buffer.writeln('  <temperature>${info.cpuTempC!.toStringAsFixed(1)}°C</temperature>');
    }
    if (info.uptimeSec != null && info.uptimeSec! > 0) {
      final hours = (info.uptimeSec! / 3600).floor();
      final mins = ((info.uptimeSec! % 3600) / 60).floor();
      buffer.writeln('  <uptime>${hours}h ${mins}m</uptime>');
    }
    buffer.writeln('</realtime_context>');

    return buffer.toString().trim();
  }

  /// Ejecutor de herramientas del chat (comandos `@` y tool-calling del LLM).
  final AgentToolDispatcher _tools;

  // ── Confirmación de herramienta (política externalWrite) ──
  // Cuando el tool-calling del LLM pide una escritura externa, la política
  // pausa el turno: se guarda la llamada + contexto de reanudación y la UI
  // muestra el diálogo. approve/reject reanudan la ronda con el resultado.

  /// Llamada pendiente de confirmación (null = nada pendiente).
  ToolCall? _pendingCall;

  /// Contexto para reanudar la ronda tras la decisión del usuario.
  String _pendingUserText = '';
  List<String> _pendingTrace = const [];
  String _pendingCallText = '';

  ChatNotifier(this._ref, {AgentToolDispatcher? toolDispatcher})
    : _tools = toolDispatcher ?? AgentToolDispatcher(),
      super(
        ChatState(
          availableModels: [for (final m in NeuralCatalog.models) m.name],
        ),
      ) {
    _restoreModel();
    _restoreMessages();
  }

  /// Test-only: emits a fixed state without IO.
  @visibleForTesting
  ChatNotifier.fixed(
    Ref ref,
    super.initial, {
    AgentToolDispatcher? toolDispatcher,
  }) : _ref = ref,
       _tools = toolDispatcher ?? AgentToolDispatcher();

  /// Restaura la última selección de modelo para que sobreviva al reinicio.
  Future<void> _restoreModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('nanoai_active_model');
      final savedPath = prefs.getString('nanoai_active_model_path');
      if (saved == null || saved.isEmpty) return;
      // El catálogo es la fuente de verdad: nombres de versiones viejas
      // (p. ej. "Qwen2.5-1.1B-Instruct") se descartan en silencio y se
      // vuelve al default en lugar de suponer un modelo inexistente.
      if (!NeuralCatalog.models.any((m) => m.name == saved)) return;
      if (!mounted) return;
      state = state.copyWith(
        activeModel: saved,
        activeModelPath: savedPath,
        connection: ModelConnectionState.loadingModel,
      );
      await _checkEngine(saved);
    } catch (e) {
      debugPrint(
        '[chat_provider] Persistencia no disponible, usando default: $e',
      );
    }
  }

  /// Clave en SharedPreferences para el historial de chat.
  static const String _historyKey = 'nanoai_chat_history';

  /// Persiste los mensajes actuales en SharedPreferences como JSON.
  Future<void> _persistMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.messages.map((m) => m.toJson()).toList());
      await prefs.setString(_historyKey, json);
    } catch (e) {
      debugPrint('[chat_provider] Error en persistencia: $e');
    }
  }

  /// Carga el historial desde SharedPreferences. Solo se llaman durante init
  /// para no pisar el estado en vivo con datos stale.
  Future<void> _restoreMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      final messages = list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      state = state.copyWith(messages: messages);
    } catch (_) {
      /* datos corruptos o no disponibles: ignorar */
    }
  }

  /// Consulta el estado real del motor (canal + /health + /api/status) y
  /// transiciona a ready/noModel/error según la evidencia. Degraded (motor
  /// vivo sin GGUF) se muestra honestamente como noModel.
  Future<void> _checkEngine([String? model]) async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    await engine.refresh();
    if (!mounted) return;
    final name = model ?? state.activeModel;
    state = state.copyWith(
      activeModel: name,
      connection: switch (engine.phase) {
        EnginePhase.ready => ModelConnectionState.ready,
        EnginePhase.degraded => ModelConnectionState.noModel,
        _ => ModelConnectionState.error,
      },
      engineOnline: engine.isLive,
    );
  }

  /// Máximo de adjuntos simultáneos en el composer. El cuarto desplaza al
  /// más antiguo (FIFO) — nunca se bloquea el gesto de adjuntar.
  static const int _maxAttachments = 3;

  /// Agrega un adjunto pendiente. Un nombre repetido reemplaza el anterior
  /// (mismo archivo re-elegido = última versión).
  void addAttachment(ChatAttachment attachment) {
    final current = [...state.attachments]
      ..removeWhere((a) => a.name == attachment.name);
    if (current.length >= _maxAttachments) {
      current.removeAt(0);
    }
    current.add(attachment);
    state = state.copyWith(attachments: current);
  }

  /// Quita un adjunto pendiente por nombre (chip con X en el composer).
  void removeAttachment(String name) {
    state = state.copyWith(
      attachments: state.attachments.where((a) => a.name != name).toList(),
    );
  }

  /// Re-comprueba la conectividad real con el motor llama.cpp y, si hay un
  /// modelo instalado, lo ARRANCA (ensureReady) en lugar de solo sondear:
  /// el botón Reintentar del empty state rompe el deadlock de arranque.
  Future<void> refreshEngine() async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    if (state.activeModelPath != null) {
      final ready = await engine.ensureReady(modelPath: state.activeModelPath);
      if (!mounted) return;
      state = state.copyWith(
        engineOnline: ready || engine.isLive,
        connection: ready
            ? ModelConnectionState.ready
            : ModelConnectionState.error,
      );
      return;
    }
    await engine.refresh();
    if (!mounted) return;
    state = state.copyWith(engineOnline: engine.isLive);
  }

  // ── Confirmación de herramienta (política §12) ────────────────────────────

  /// El usuario aprobó la herramienta pendiente: se ejecuta con
  /// `confirmed: true` y la ronda continúa con el resultado en el trace.
  Future<void> approvePendingTool() async {
    final call = _pendingCall;
    if (call == null || state.pendingTool == null) return;
    final userText = _pendingUserText;
    final trace = _pendingTrace;
    final callText = _pendingCallText;
    _pendingCall = null;
    state = state.copyWith(
      generating: true,
      pendingTool: null,
      pendingToolDescription: null,
    );
    final outcome = await _tools.runToolGuarded(call, confirmed: true);
    if (!mounted || _generationCancelled) return;
    await _generateRound(userText, [
      ...trace,
      callText,
      outcome.feedback,
    ], const []);
  }

  /// El usuario rechazó la herramienta pendiente: nada se ejecuta y la ronda
  /// continúa con el rechazo en el trace (el modelo ve el motivo y cierra).
  Future<void> rejectPendingTool() async {
    final call = _pendingCall;
    if (call == null || state.pendingTool == null) return;
    final userText = _pendingUserText;
    final trace = _pendingTrace;
    final callText = _pendingCallText;
    _pendingCall = null;
    state = state.copyWith(
      generating: true,
      pendingTool: null,
      pendingToolDescription: null,
    );
    await _generateRound(userText, [
      ...trace,
      callText,
      '🚫 [policy] ${call.tool} cancelada por el usuario (sin confirmación).',
    ], const []);
  }

  /// Envía [text] al motor como mensaje del usuario.
  /// [setInput] es innecesario: `send` recibe el texto directamente.
  ///
  /// El motor es responsabilidad de RuntimeEngineNotifier: si no está listo
  /// (idle/failed), se arranca aquí con ensureReady() antes de generar. Si
  /// queda degraded (motor vivo sin GGUF), se inserta un error honesto en
  /// el chat en lugar de una generación que siempre fallaría con 503.
  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.generating) return;

    if (!state.engineOnline && state.activeModelPath == null) {
      final errorMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text:
            'No hay un modelo seleccionado. Por favor, ve a la pestaña Modelos y selecciona uno para poder chatear.',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(messages: [...state.messages, errorMsg]);
      return;
    }

    // Nuevo turno del usuario: resetea el presupuesto de pasos de la
    // política y descarta cualquier confirmación pendiente vieja.
    _tools.resetTurn();
    _pendingCall = null;
    if (state.pendingTool != null) {
      state = state.copyWith(pendingTool: null, pendingToolDescription: null);
    }
    // Captura y consume los adjuntos pendientes: viajan SOLO con este
    // mensaje y se inyectan al prompt real de la generación.
    final attachments = state.attachments;
    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      text: t,
      timestamp: DateTime.now(),
      attachmentNames: [for (final a in attachments) a.name],
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      input: '',
      generating: true,
      streamingText: '',
      attachments: const [],
    );
    _persistMessages(); // guardar el user msg inmediatamente

    // Comandos `@`: ejecución determinista sin LLM. Funcionan incluso con
    // el motor degradado (vivo sin GGUF) — no consumen tokens ni ensureReady.
    if (AgentToolDispatcher.isToolCommand(t)) {
      final result = await _tools.runCommand(t);
      if (!mounted) return;
      final toolMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: result,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
      state = state.copyWith(
        messages: [...state.messages, toolMsg],
        generating: false,
        streamingText: '',
      );
      _persistMessages();
      return;
    }

    final engine = _ref.read(runtimeEngineProvider.notifier);
    final ready = await engine.ensureReady(modelPath: state.activeModelPath);
    if (!mounted) return;
    if (!ready) {
      final degraded = engine.phase == EnginePhase.degraded;
      final errMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: degraded
            ? 'El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo de modelos.'
                        : 'El motor no pudo arrancar: ${engine.reason ?? "fallo desconocido"}.',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(
        messages: [...state.messages, errMsg],
        generating: false,
        streamingText: '',
        connection: degraded
            ? ModelConnectionState.noModel
            : ModelConnectionState.error,
        engineOnline: engine.isLive,
      );
      _persistMessages();
      return;
    }
    if (!mounted) return;
    state = state.copyWith(
      connection: ModelConnectionState.ready,
      engineOnline: true,
    );
    _generate(t, attachments);
  }

  /// Construye el prompt multi-turno según el [ChatTemplate] del modelo activo.
  /// Delega a [_buildQwenPrompt] o [_buildDeepSeekPrompt] según corresponda.
  String _buildChatPrompt(
    List<ChatMessage> history,
    String newUserText,
    List<ChatAttachment> attachments, {
    bool openAssistantTurn = true,
  }) {
    final template = NeuralCatalog.templateOf(state.activeModel);
    switch (template) {
      case ChatTemplate.deepseek:
        return _buildDeepSeekPrompt(
          history,
          newUserText,
          attachments,
          openAssistantTurn: openAssistantTurn,
        );
      case ChatTemplate.qwen:
        return _buildQwenPrompt(
          history,
          newUserText,
          attachments,
          openAssistantTurn: openAssistantTurn,
        );
    }
  }

  /// Neutraliza tokens especiales que podrían cerrar/abrir roles del modelo
  /// cuando provienen de usuario, historial, adjuntos o resultados de tools.
  String _promptSafe(String value) => value
      .replaceAll('<|im_start|>', '< |im_start| >')
      .replaceAll('<|im_end|>', '< |im_end| >')
      .replaceAll(
        '<\uFF5Cbegin\u2581of\u2581sentence\uFF5C>',
        '< |begin_of_sentence| >',
      )
      .replaceAll(
        '<\uFF5Cend\u2581of\u2581sentence\uFF5C>',
        '< |end_of_sentence| >',
      );

  String _promptClip(String value, int maxChars) {
    final safe = _promptSafe(value);
    if (safe.length <= maxChars) return safe;
    return '${safe.substring(0, maxChars)}\n[recortado]';
  }

  /// Bloque de adjuntos que se inyecta al turno user del prompt: contenido
  /// REAL del archivo, delimitado para que el modelo lo distinga del texto
  /// escrito por el usuario.
  String _attachmentsBlock(List<ChatAttachment> attachments) {
    final buffer = StringBuffer();
    for (final a in attachments) {
      buffer
        ..writeln('[Adjunto: ${_promptClip(a.name, 160)}]')
        ..writeln(_promptClip(a.content, _maxAttachmentChars))
        ..writeln('[Fin de adjunto]');
    }
    return buffer.toString();
  }

  /// Prompt en formato Qwen (ChatML-like):
  String _buildQwenPrompt(
    List<ChatMessage> history,
    String newUserText,
    List<ChatAttachment> attachments, {
    bool openAssistantTurn = true,
  }) {
    final buffer = StringBuffer();
    buffer.write('<|im_start|>system\n${_buildSystemPrompt()}<|im_end|>\n');
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.write(
        '<|im_start|>$role\n${_promptClip(msg.text, _maxHistoryChars)}<|im_end|>\n',
      );
    }
    buffer.write(
      '<|im_start|>user\n${_attachmentsBlock(attachments)}'
      '${_promptClip(newUserText, _maxUserChars)}<|im_end|>\n',
    );
    if (openAssistantTurn) {
      buffer.write('<|im_start|>assistant\n');
    }
    return buffer.toString();
  }

  /// Prompt en formato DeepSeek-R1:
  String _buildDeepSeekPrompt(
    List<ChatMessage> history,
    String newUserText,
    List<ChatAttachment> attachments, {
    bool openAssistantTurn = true,
  }) {
    // Tokens especiales native de DeepSeek-R1.
    const bos = '<｜begin▁of▁sentence｜>';
    const eos = '<｜end▁of▁sentence｜>';
    final buffer = StringBuffer();
    buffer.write('$bos\nsystem\n${_buildSystemPrompt()}\n$eos\n');
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.write('$bos$role\n${_promptSafe(msg.text)}\n$eos\n');
    }
    buffer.write(
      '$bos\nuser\n${_attachmentsBlock(attachments)}'
      '${_promptSafe(newUserText)}\n$eos\n',
    );
    if (openAssistantTurn) {
      buffer.write('$bos\nassistant\n');
    }
    return buffer.toString();
  }

  /// Turnos de herramienta para el trace: la llamada JSON como assistant y
  /// el resultado real como user, listos para que el modelo continúe.
  String _toolTurnSuffix(String toolCall, String result) {
    final template = NeuralCatalog.templateOf(state.activeModel);
    switch (template) {
      case ChatTemplate.deepseek:
        const bos = '<｜begin▁of▁sentence｜>';
        const eos = '<｜end▁of▁sentence｜>';
        return '$bos\nassistant\n${_promptSafe(toolCall)}\n$eos\n'
            '$bos\nuser\nResultado de la herramienta:\n'
            '${_promptSafe(result)}\n$eos\n'
            '$bos\nassistant\n';
      case ChatTemplate.qwen:
        return '<|im_start|>assistant\n'
            '${_promptClip(toolCall, _maxToolTraceChars)}<|im_end|>\n'
            '<|im_start|>user\nResultado de la herramienta:\n'
            '${_promptClip(result, _maxToolTraceChars)}<|im_end|>\n'
            '<|im_start|>assistant\n';
    }
  }

  /// Programa el siguiente flush del texto parcial si no hay uno pendiente.
  void _scheduleStreamFlush(StringBuffer buffer) {
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 32), () {
      _flushTimer = null;
      if (mounted && !_generationCancelled) {
        state = state.copyWith(streamingText: buffer.toString());
      }
    });
  }

  /// Cancela cualquier flush pendiente.
  void _cancelStreamFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  bool _requiresAutonomousToolConfirmation(ToolCall call) {
    final mode = _ref.read(settingsProvider).agentAutomationMode;
    return switch (mode) {
      AgentAutomationMode.manual =>
        call.tool != 'screen' && call.tool != 'resolve',
      AgentAutomationMode.assisted =>
        call.tool == 'tap' || call.tool == 'back' || call.tool == 'write',
      AgentAutomationMode.autonomous => call.tool == 'write',
    };
  }

  String _toolConfirmationDescription(ToolCall call) {
    final mode = _ref.read(settingsProvider).agentAutomationMode;
    return '[policy] "${call.tool}" requiere confirmación en modo ${mode.label} antes de actuar sobre el dispositivo.';
  }

  Future<void> _generate(String text, List<ChatAttachment> attachments) =>
      _generateRound(text, const <String>[], attachments);

  /// Devuelve el historial anterior al turno user actual. En rondas con tools,
  /// el estado ya contiene mensajes assistant con llamadas JSON visibles;
  /// esos mensajes pertenecen al turno en curso y se reinyectan vía toolTrace.
  List<ChatMessage> _historyBeforeCurrentUser(String text) {
    for (var i = state.messages.length - 1; i >= 0; i--) {
      final msg = state.messages[i];
      if (msg.sender == MessageSender.user && msg.text == text) {
        return state.messages.sublist(0, i);
      }
    }
    return state.messages;
  }

  /// Una ronda de generación. [toolTrace] contiene pares
  /// (llamadaJSON, resultado) de herramientas ya ejecutadas en este turno;
  /// se inyectan al prompt como turnos assistant/user para que el modelo
  /// continúe informado del resultado real.
  ///
  /// [attachments] se inyecta al prompt base SOLO en la primera ronda:
  /// el contenido ya está en el contexto de las rondas siguientes.
  Future<void> _generateRound(
    String text,
    List<String> toolTrace,
    List<ChatAttachment> attachments,
  ) async {
    _generationCancelled = false;
    // El historial YA incluye el turno actual y, si hubo tools, sus trazas
    // visibles. Se excluye todo eso para que el prompt no duplique turnos.
    final history = _historyBeforeCurrentUser(text);
    var prompt = _buildChatPrompt(
      history,
      text,
      toolTrace.isEmpty ? attachments : const <ChatAttachment>[],
      openAssistantTurn: toolTrace.isEmpty,
    );
    for (var i = 0; i + 1 < toolTrace.length; i += 2) {
      prompt += _toolTurnSuffix(toolTrace[i], toolTrace[i + 1]);
    }

    // Streaming: cada token actualiza streamingText en tiempo real.
    final settings = _ref.read(settingsProvider);
    final (:stream, :client) = _engine.generateStream(
      prompt: prompt,
      temperature: settings.temperature,
      topP: settings.topP,
      maxTokens: settings.maxTokens.clamp(32, 2048),
      sessionId: _sessionId,
    );
    _streamClient = client;

    try {
      final buffer = StringBuffer();
      double? finalTps;
      await for (final token in stream.timeout(
        _streamIdleTimeout,
        onTimeout: (sink) {
          sink.addError(
            LLMEngineException(
              'Timeout: el motor no emitió tokens durante '
              '${_streamIdleTimeout.inSeconds}s',
            ),
          );
        },
      )) {
        if (_generationCancelled || !mounted) {
          _streamClient?.close();
          _streamClient = null;
          return;
        }
        if (token.stop) {
          finalTps = token.tps;
          break;
        }
        buffer.write(token.content);
        // Throttle: UI se actualiza cada ~32ms
        _scheduleStreamFlush(buffer);
      }

      // Flush del texto parcial restante
      _cancelStreamFlush();

      if (_generationCancelled || !mounted) return;

      final fullText = buffer.toString().trim();
      if (fullText.isEmpty) {
        final emptyMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text:
              'El motor terminó sin emitir texto. Esto suele indicar '
              'modelo no cargado, prompt rechazado por el runtime o falta de '
              'memoria durante la inferencia.',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        );
        state = state.copyWith(
          messages: [...state.messages, emptyMsg],
          generating: false,
          streamingText: '',
          connection: ModelConnectionState.error,
          engineOnline: true,
        );
        _persistMessages();
        return;
      }

      // Tool-calling: si el modelo respondió una llamada a herramienta,
      // ejecutarla (bajo política §12) y re-generar con el resultado en el
      // trace. Una escritura externa pausa el turno a la espera de
      // confirmación del usuario (approvePendingTool/rejectPendingTool).
      final toolCall = AgentToolProtocol.extractToolCall(fullText);
      if (toolCall != null && toolTrace.length ~/ 2 < _maxToolRounds) {
        // La llamada queda visible en el chat (trace honesto del agente).
        final toolMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: fullText,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        );
        state = state.copyWith(
          messages: [...state.messages, toolMsg],
          streamingText: '',
        );
        _persistMessages();

        if (_requiresAutonomousToolConfirmation(toolCall)) {
          _pendingCall = toolCall;
          _pendingUserText = text;
          _pendingTrace = toolTrace;
          _pendingCallText = fullText;
          state = state.copyWith(
            generating: false,
            pendingTool: toolCall.tool,
            pendingToolDescription: _toolConfirmationDescription(toolCall),
          );
          return;
        }

        final outcome = await _tools.runToolGuarded(toolCall);
        if (!mounted || _generationCancelled) return;
        if (outcome.needsConfirmation) {
          // Pausa: guardar contexto de reanudación y exponer el diálogo.
          _pendingCall = toolCall;
          _pendingUserText = text;
          _pendingTrace = toolTrace;
          _pendingCallText = fullText;
          state = state.copyWith(
            generating: false,
            pendingTool: toolCall.tool,
            pendingToolDescription: outcome.feedback,
          );
          return;
        }
        await _generateRound(text, [
          ...toolTrace,
          fullText,
          outcome.feedback,
        ], const []);
        return;
      }

      final sanitizedText = fullText
          .replaceAll('<|im_end|>', '')
          .replaceAll('<|im_start|>', '')
          .replaceAll('<|endoftext|>', '')
          .replaceAll('<\uFF5Cend\u2581of\u2581sentence\uFF5C>', '')
          .replaceAll('<\uFF5Cbegin\u2581of\u2581sentence\uFF5C>', '')
          .trim();

      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: sanitizedText.isEmpty ? fullText : sanitizedText,
        timestamp: DateTime.now(),
        tps: finalTps,
        status: MessageStatus.sent,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        generating: false,
        streamingText: '',
        connection: ModelConnectionState.ready,
        engineOnline: true,
        liveTps: finalTps ?? state.liveTps,
      );
      _persistMessages();
    } on LLMEngineException catch (e) {
      if (!mounted || _generationCancelled) return;
      // Distinguir 503 runtime_unavailable (motor vivo sin GGUF) del resto:
      // el mensaje honesto cambia y connection pasa a noModel, no a error.
      final engine = _ref.read(runtimeEngineProvider.notifier);
      final degraded = engine.phase == EnginePhase.degraded;
      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: degraded
            ? 'El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo de modelos. (${state.activeModel})'
                        : 'El motor llama.cpp no respondió: ${e.message}. (${state.activeModel})',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        generating: false,
        streamingText: '',
        connection: degraded
            ? ModelConnectionState.noModel
            : ModelConnectionState.error,
        engineOnline: engine.isLive,
      );
      _persistMessages();
    } finally {
      _cancelStreamFlush();
      _streamClient = null;
    }
  }

  // STOP cancela la respuesta PENDIENTE
  void stop() {
    _generationCancelled = true;
    // Cancelar el flush pendiente ANTES de cerrar el cliente: evita que un
    // timer de 32ms escriba streamingText residual con generating=false.
    _cancelStreamFlush();
    _streamClient?.close();
    _streamClient = null;
    state = state.copyWith(generating: false, streamingText: '');
    _persistMessages();
  }

  Future<void> clear() async {
    if (state.generating) stop();
    _sessionId = _newSessionId();
    state = state.copyWith(messages: [], input: '', streamingText: '');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      debugPrint('[chat_provider] Error en persistencia: $e');
    }
  }

  void delete(String id) {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != id).toList(),
    );
    _persistMessages();
  }

  /// Reintenta el envío tras un error
  void retry(String errorMessageId) {
    if (state.generating) return;
    final msgs = state.messages;
    final errIdx = msgs.indexWhere((m) => m.id == errorMessageId);
    if (errIdx < 1) return;
    
    // Buscar el último mensaje del usuario antes del mensaje de error
    ChatMessage? userMsg;
    for (var i = errIdx - 1; i >= 0; i--) {
      if (msgs[i].sender == MessageSender.user) {
        userMsg = msgs[i];
        break;
      }
    }
    if (userMsg == null) return;

    // Eliminar AMBOS: el error y el mensaje del usuario
    final newMsgs = msgs
        .where((m) => m.id != errorMessageId && m.id != userMsg!.id)
        .toList();
    state = state.copyWith(messages: newMsgs);
    _persistMessages();
    // catchError evita que un fallo en send() quede huérfano en un Future
    // sin listener (unawaited + throw → análisis de errores lo pierde).
    unawaited(
      send(userMsg.text).catchError(
        (Object e) => debugPrint('[chat_provider] retry send error: $e'),
      ),
    );
  }

  void selectModel(String name, {String? path}) {
    // SELinux impide que la app rearranque el motor per-selección.
    state = state.copyWith(
      activeModel: name,
      activeModelPath: path ?? state.activeModelPath,
      connection: ModelConnectionState.loadingModel,
      showModelSelector: false,
    );
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(milliseconds: 600), () async {
      _loadTimer = null;
      await _checkEngine(name);
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nanoai_active_model', name);
        if (path != null) {
          await prefs.setString('nanoai_active_model_path', path);
        }
      } catch (e) {
        debugPrint('[chat_provider] Error en persistencia: $e');
      }
    });
  }

  @override
  void dispose() {
    _cancelStreamFlush();
    _streamClient?.close();
    _loadTimer?.cancel();
    // El client es propiedad de RuntimeEngineNotifier: él lo dispone.
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(ref),
);
