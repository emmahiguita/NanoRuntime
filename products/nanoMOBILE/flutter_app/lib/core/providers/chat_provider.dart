import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../agent/agent_tool_dispatcher.dart';
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

  /// Número máximo de mensajes enviados al motor como historial (40 = ~20 turnos).
  /// Los modelos GGUF pequeños (1B-7B) tienen ventanas de contexto limitadas
  /// (8K-32K tokens). 40 mensajes mantienen el prompt bajo ~4K tokens en uso típico.
  static const int _maxHistoryMessages = 40;

  /// Máximo de rondas de herramienta por mensaje del usuario: evita bucles
  /// infinitos si el modelo insiste en llamar tools sin concluir.
  static const int _maxToolRounds = 2;

  /// System prompt inyectado al inicio de cada conversación multi-turno.
  /// Define el comportamiento base del asistente para todos los modelos.
  /// El contrato de herramientas es JSON de una línea (formato que los
  /// GGUF 1B-7B pueden seguir; el parseo tolera prosa alrededor).
  static const String _systemPrompt =
      'Eres NanoAI, un asistente que corre 100% '
      'en el dispositivo, sin conexión a internet. Responde de forma concisa, '
      'técnica y útil. Si no sabes algo, dilo con honestidad.\n\n'
      'Puedes controlar la interfaz del dispositivo. Para usar una '
      'herramienta responde EXACTAMENTE un JSON en una línea, sin markdown '
      'ni texto extra:\n'
      '{"tool":"screen"} — leer la pantalla actual\n'
      '{"tool":"tap","selector":"<sel>"} — tocar un elemento\n'
      '{"tool":"write","selector":"<sel>","text":"<texto>"} — escribir en '
      'un campo\n'
      '{"tool":"back"} — botón atrás\n'
      'Selector: text=..., desc=..., id=..., role=..., editable=true, '
      'separados por ";" (ej: text=Bluetooth, editable=true;near=desc=Usuario). '
      'Tras la herramienta recibirás el resultado y responderás al usuario '
      'con base en él.';

  /// Ejecutor de herramientas del chat (comandos `@` y tool-calling del LLM).
  final AgentToolDispatcher _tools;

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
  ChatNotifier.fixed(Ref ref, super.initial, {AgentToolDispatcher? toolDispatcher})
    : _ref = ref,
      _tools = toolDispatcher ?? AgentToolDispatcher();

  /// Restaura la última selección de modelo para que sobreviva al reinicio.
  Future<void> _restoreModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('nanoai_active_model');
      if (saved == null || saved.isEmpty) return;
      // El catálogo es la fuente de verdad: nombres de versiones viejas
      // (p. ej. "Qwen2.5-1.1B-Instruct") se descartan en silencio y se
      // vuelve al default en lugar de suponer un modelo inexistente.
      if (!NeuralCatalog.models.any((m) => m.name == saved)) return;
      if (!mounted) return;
      state = state.copyWith(
        activeModel: saved,
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

  void setInput(String v) => state = state.copyWith(input: v);

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
            ? '⚠️ El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo de modelos.'
            : '⚠️ El motor no pudo arrancar: ${engine.reason ?? "fallo desconocido"}.',
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
    List<ChatAttachment> attachments,
  ) {
    final template = NeuralCatalog.templateOf(state.activeModel);
    switch (template) {
      case ChatTemplate.deepseek:
        return _buildDeepSeekPrompt(history, newUserText, attachments);
      case ChatTemplate.qwen:
        return _buildQwenPrompt(history, newUserText, attachments);
    }
  }

  /// Bloque de adjuntos que se inyecta al turno user del prompt: contenido
  /// REAL del archivo, delimitado para que el modelo lo distinga del texto
  /// escrito por el usuario.
  String _attachmentsBlock(List<ChatAttachment> attachments) {
    final buffer = StringBuffer();
    for (final a in attachments) {
      buffer
        ..writeln('[Adjunto: ${a.name}]')
        ..writeln(a.content)
        ..writeln('[Fin de adjunto]');
    }
    return buffer.toString();
  }

  /// Prompt en formato Qwen (ChatML-like):
  String _buildQwenPrompt(
    List<ChatMessage> history,
    String newUserText,
    List<ChatAttachment> attachments,
  ) {
    final buffer = StringBuffer();
    buffer.write('<|im_start|>system\n$_systemPrompt<|im_end|>\n');
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.write('<|im_start|>$role\n${msg.text}<|im_end|>\n');
    }
    buffer.write(
      '<|im_start|>user\n${_attachmentsBlock(attachments)}$newUserText'
      '<|im_end|>\n',
    );
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  /// Prompt en formato DeepSeek-R1:
  String _buildDeepSeekPrompt(
    List<ChatMessage> history,
    String newUserText,
    List<ChatAttachment> attachments,
  ) {
    // Tokens especiales native de DeepSeek-R1.
    const bos = '<｜begin▁of▁sentence｜>';
    const eos = '<｜end▁of▁sentence｜>';
    final buffer = StringBuffer();
    buffer.write('$bos\nsystem\n$_systemPrompt\n$eos\n');
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.write('$bos$role\n${msg.text}\n$eos\n');
    }
    buffer.write(
      '$bos\nuser\n${_attachmentsBlock(attachments)}$newUserText\n$eos\n',
    );
    buffer.write('$bos\nassistant\n');
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
        return '$bos\nassistant\n$toolCall\n$eos\n'
            '$bos\nuser\nResultado de la herramienta:\n$result\n$eos\n'
            '$bos\nassistant\n';
      case ChatTemplate.qwen:
        return '<|im_start|>assistant\n$toolCall<|im_end|>\n'
            '<|im_start|>user\nResultado de la herramienta:\n'
            '$result<|im_end|>\n'
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

  Future<void> _generate(
    String text,
    List<ChatAttachment> attachments,
  ) => _generateRound(text, const <String>[], attachments);

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
    // El historial YA incluye el mensaje del usuario recién enviado (en send()).
    // Lo excluimos del historial para evitar duplicarlo.
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : <ChatMessage>[];
    var prompt = _buildChatPrompt(
      history,
      text,
      toolTrace.isEmpty ? attachments : const <ChatAttachment>[],
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
      maxTokens: settings.maxTokens,
    );
    _streamClient = client;

    try {
      final buffer = StringBuffer();
      double? finalTps;
      await for (final token in stream) {
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
          text: '(sin respuesta)',
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        );
        state = state.copyWith(
          messages: [...state.messages, emptyMsg],
          generating: false,
          streamingText: '',
          connection: ModelConnectionState.ready,
          engineOnline: true,
        );
        _persistMessages();
        return;
      }

      // Tool-calling: si el modelo respondió una llamada a herramienta,
      // ejecutarla y re-generar con el resultado en el trace.
      final toolCall = AgentToolProtocol.extractToolCall(fullText);
      if (toolCall != null && toolTrace.length ~/ 2 < _maxToolRounds) {
        final result = await _tools.runTool(toolCall);
        if (!mounted || _generationCancelled) return;
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
        await _generateRound(text, [...toolTrace, fullText, result], const []);
        return;
      }

      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: fullText,
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
    } on LLMEngineException catch (_) {
      if (!mounted || _generationCancelled) return;
      // Distinguir 503 runtime_unavailable (motor vivo sin GGUF) del resto:
      // el mensaje honesto cambia y connection pasa a noModel, no a error.
      final engine = _ref.read(runtimeEngineProvider.notifier);
      final degraded = engine.phase == EnginePhase.degraded;
      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: degraded
            ? '⚠️ El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo de modelos. (${state.activeModel})'
            : '⚠️ El motor llama.cpp no respondió. Confirma que esté levantado en el dispositivo y vuelve a intentarlo. (${state.activeModel})',
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
    _streamClient?.close();
    _streamClient = null;
    state = state.copyWith(generating: false, streamingText: '');
    _persistMessages();
  }

  void clear() async {
    // Vaciar mensajes ANTES de cancelar la generación
    state = state.copyWith(messages: [], input: '');
    if (state.generating) stop();
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
    final userMsg = msgs[errIdx - 1];
    if (userMsg.sender != MessageSender.user) return;
    // Eliminar AMBOS: el error y el mensaje del usuario
    final newMsgs = msgs
        .where((m) => m.id != errorMessageId && m.id != userMsg.id)
        .toList();
    state = state.copyWith(messages: newMsgs);
    _persistMessages();
    unawaited(send(userMsg.text));
  }

  void toggleSelector() =>
      state = state.copyWith(showModelSelector: !state.showModelSelector);

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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nanoai_active_model', name);
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
