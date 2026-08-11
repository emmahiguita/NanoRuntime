import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/llm_engine_client.dart';
import '../models/chat_models.dart';
import '../models/catalog_models.dart';
import 'settings_provider.dart';

// ================================================================
// Chat State and Notifier
// ================================================================

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  // Motor llama.cpp real desplegado en el dispositivo (loopback 127.0.0.1:8080).
  final LLMEngineClient _engine = LLMEngineClient();
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

  /// System prompt inyectado al inicio de cada conversación multi-turno.
  /// Define el comportamiento base del asistente para todos los modelos.
  static const String _systemPrompt = 'Eres NanoAI, un asistente que corre 100% '
      'en el dispositivo, sin conexión a internet. Responde de forma concisa, '
      'técnica y útil. Si no sabes algo, dilo con honestidad.';

  ChatNotifier(this._ref) : super(ChatState(availableModels: [for (final m in NeuralCatalog.models) m.name])) {
    _restoreModel();
    _restoreMessages();
  }

  /// Restaura la última selección de modelo para que sobreviva al reinicio.
  Future<void> _restoreModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('nanoai_active_model');
      if (saved == null || saved.isEmpty) return;
      if (!mounted) return;
      state = state.copyWith(activeModel: saved, connection: ModelConnectionState.loadingModel);
      await _checkEngine(saved);
    } catch (e) {
      debugPrint('[chat_provider] Persistencia no disponible, usando default: $e');
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

  /// Consulta /health y transiciona a ready/error según el motor real.
  Future<void> _checkEngine([String? model]) async {
    final online = await _engine.isOnline();
    if (!mounted) return;
    final name = model ?? state.activeModel;
    state = state.copyWith(
      activeModel: name,
      connection: online ? ModelConnectionState.ready : ModelConnectionState.error,
      engineOnline: online,
    );
  }

  void setInput(String v) => state = state.copyWith(input: v);

  /// Re-comprueba la conectividad real con el motor llama.cpp.
  Future<void> refreshEngine() async {
    final online = await _engine.isOnline();
    if (!mounted) return;
    state = state.copyWith(engineOnline: online);
  }

  /// Envía [text] al motor como mensaje del usuario.
  /// [setInput] es innecesario: `send` recibe el texto directamente.
  void send(String text) {
    final t = text.trim();
    if (t.isEmpty || state.generating || state.connection != ModelConnectionState.ready) return;
    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      text: t,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, userMsg], input: '', generating: true, streamingText: '');
    _persistMessages(); // guardar el user msg inmediatamente
    _generate(t);
  }

  /// Construye el prompt multi-turno según el [ChatTemplate] del modelo activo.
  /// Delega a [_buildQwenPrompt] o [_buildDeepSeekPrompt] según corresponda.
  String _buildChatPrompt(List<ChatMessage> history, String newUserText) {
    final template = NeuralCatalog.templateOf(state.activeModel);
    switch (template) {
      case ChatTemplate.deepseek:
        return _buildDeepSeekPrompt(history, newUserText);
      case ChatTemplate.qwen:
        return _buildQwenPrompt(history, newUserText);
    }
  }

  /// Prompt en formato Qwen (ChatML-like):
  String _buildQwenPrompt(List<ChatMessage> history, String newUserText) {
    final buffer = StringBuffer();
    buffer.write('<|im_start|>system\n$_systemPrompt<|im_end|>\n');
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.write('<|im_start|>$role\n${msg.text}<|im_end|>\n');
    }
    buffer.write('<|im_start|>user\n$newUserText<|im_end|>\n');
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  /// Prompt en formato DeepSeek-R1:
  String _buildDeepSeekPrompt(List<ChatMessage> history, String newUserText) {
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
    buffer.write('$bos\nuser\n$newUserText\n$eos\n');
    buffer.write('$bos\nassistant\n');
    return buffer.toString();
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

  Future<void> _generate(String text) async {
    _generationCancelled = false;
    // El historial YA incluye el mensaje del usuario recién enviado (en send()).
    // Lo excluimos del historial para evitar duplicarlo.
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : <ChatMessage>[];
    final prompt = _buildChatPrompt(history, text);

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
      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: '⚠️ El motor llama.cpp no respondió. Confirma que esté levantado en el dispositivo y vuelve a intentarlo. (${state.activeModel})',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        generating: false,
        streamingText: '',
        engineOnline: false,
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
    state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
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
    final newMsgs = msgs.where((m) => m.id != errorMessageId && m.id != userMsg.id).toList();
    state = state.copyWith(messages: newMsgs);
    _persistMessages();
    send(userMsg.text);
  }

  void toggleSelector() => state = state.copyWith(showModelSelector: !state.showModelSelector);

  void selectModel(String name) {
    // SELinux impide que la app rearranque el motor per-selección.
    state = state.copyWith(
      activeModel: name,
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
    _engine.dispose();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
