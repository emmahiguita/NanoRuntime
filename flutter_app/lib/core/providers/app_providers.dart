import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_metrics.dart';
import '../services/llm_engine_client.dart';
import '../services/rootfs_manager.dart';

/* ================================================================
   NanoAI — Real State Management
   Persistence: SharedPreferences. Reactivity: Riverpod StateNotifier.
   ================================================================ */

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// ─── Settings Repository (real persistence) ───
class SettingsRepository {
  static const _k = 'nanoai_settings';
  late SharedPreferences _prefs;
  bool _ready = false;

  Future<void> init() async { _prefs = await SharedPreferences.getInstance(); _ready = true; }

  SettingsState load() {
    if (!_ready) return const SettingsState();
    final json = _prefs.getString(_k);
    if (json == null) return const SettingsState();
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return SettingsState(
        themeMode: m['themeMode'] as String? ?? 'Sistema',
        temperature: (m['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (m['topP'] as num?)?.toDouble() ?? 0.9,
        madvise: m['madvise'] as bool? ?? true,
        oomGuard: m['oomGuard'] as bool? ?? true,
        thermalLimit: (m['thermalLimit'] as num?)?.toDouble() ?? 42,
        batteryMode: m['batteryMode'] as String? ?? 'Balanced',
        maxTokens: (m['maxTokens'] as num?)?.toInt() ?? 512,
      );
    } catch (_) { return const SettingsState(); }
  }

  Future<void> save(SettingsState s) async {
    if (!_ready) await init();
    await _prefs.setString(_k, jsonEncode({
      'themeMode': s.themeMode, 'temperature': s.temperature, 'topP': s.topP,
      'madvise': s.madvise, 'oomGuard': s.oomGuard, 'thermalLimit': s.thermalLimit, 'batteryMode': s.batteryMode,
      'maxTokens': s.maxTokens,
    }));
  }
}

final settingsRepoProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

// ─── Settings State (identical to before but with persistence) ───
class SettingsState {
  final String themeMode; final double temperature, topP; final bool madvise, oomGuard; final double thermalLimit; final String batteryMode;
  /// Tokens máximos que el motor generará por respuesta. 512 por defecto.
  final int maxTokens;
  const SettingsState({this.themeMode = 'Sistema', this.temperature = 0.7, this.topP = 0.9, this.madvise = true, this.oomGuard = true, this.thermalLimit = 42, this.batteryMode = 'Balanced', this.maxTokens = 512});

  SettingsState copyWith({String? themeMode, double? temperature, double? topP, bool? madvise, bool? oomGuard, double? thermalLimit, String? batteryMode, int? maxTokens}) =>
    SettingsState(themeMode: themeMode ?? this.themeMode, temperature: temperature ?? this.temperature, topP: topP ?? this.topP, madvise: madvise ?? this.madvise, oomGuard: oomGuard ?? this.oomGuard, thermalLimit: thermalLimit ?? this.thermalLimit, batteryMode: batteryMode ?? this.batteryMode, maxTokens: maxTokens ?? this.maxTokens);
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo; final Ref _ref;
  SettingsNotifier(this._repo, this._ref) : super(const SettingsState());

  Future<void> init() async {
    await _repo.init();
    state = _repo.load();
    // Sync theme to themeModeProvider
    _ref.read(themeModeProvider.notifier).state = state.themeMode == 'Oscuro' ? ThemeMode.dark : state.themeMode == 'Claro' ? ThemeMode.light : ThemeMode.system;
  }

  Future<void> _persist(SettingsState s) async { state = s; await _repo.save(s); }
  void setThemeMode(String m) { _persist(state.copyWith(themeMode: m)); _ref.read(themeModeProvider.notifier).state = m == 'Oscuro' ? ThemeMode.dark : m == 'Claro' ? ThemeMode.light : ThemeMode.system; }
  void setTemperature(double v) => _persist(state.copyWith(temperature: v));
  void setTopP(double v) => _persist(state.copyWith(topP: v));
  void toggleMadvise(bool v) => _persist(state.copyWith(madvise: v));
  void toggleOom(bool v) => _persist(state.copyWith(oomGuard: v));
  void setThermalLimit(double v) => _persist(state.copyWith(thermalLimit: v));
  void setBatteryMode(String v) => _persist(state.copyWith(batteryMode: v));
  void setMaxTokens(int v) => _persist(state.copyWith(maxTokens: v));
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) => SettingsNotifier(ref.read(settingsRepoProvider), ref));

// ─── Chat State (real timer-based response, model state management) ───
/// Catálogo REAL de modelos GGUF presentes en el dispositivo
/// (/data/local/tmp/*.gguf). La app no puede listar el FS del device
/// (SELinux bloquea el acceso desde el uid de la app), por eso se
/// declaran aquí con los datos reales verificados por adb.
///
/// Un solo llama-server corre a la vez: cambiar de modelo requiere
/// reiniciar el motor vía adb. La selección en la app persiste el
/// catálogo pero no rearranca el server (restringido por SELinux).
class LmCatalogEntry {
  final String name; final String params; final String quant; final double sizeGb; final double ramGb; final String file;
  /// Template de chat que espera este modelo para conversaciones multi-turno.
  /// Qwen usa `<|im_start|>`, DeepSeek-R1 usa `<｜begin▁of▁sentence｜>`.
  final ChatTemplate template;
  const LmCatalogEntry(this.name, this.params, this.quant, this.sizeGb, this.ramGb, this.file, {this.template = ChatTemplate.qwen});
}

abstract final class NeuralCatalog {
  static const models = <LmCatalogEntry>[
    LmCatalogEntry('Qwen2.5-1.1B-Instruct', '1.1B', 'Q8_0', 1.12, 1.8, 'qwen.gguf', template: ChatTemplate.qwen),
    LmCatalogEntry('Qwen2.5-3B-Instruct', '3B', 'Q8_0', 2.10, 2.8, 'qwen3b.gguf', template: ChatTemplate.qwen),
    LmCatalogEntry('DeepSeek-R1-7B', '7B', 'Q4_K_M', 4.68, 3.6, 'deepseek.gguf', template: ChatTemplate.deepseek),
    LmCatalogEntry('DeepSeek-R1-7B-Q2', '7B', 'Q2_K', 3.01, 2.2, 'deepseek-q2k.gguf', template: ChatTemplate.deepseek),
  ];
  static String fileOf(String name) => models.firstWhere((m) => m.name == name, orElse: () => models[0]).file;
  /// Devuelve el [ChatTemplate] del modelo por nombre, o [ChatTemplate.qwen] por defecto.
  static ChatTemplate templateOf(String name) => models.firstWhere((m) => m.name == name, orElse: () => models[0]).template;
}

enum ModelConnectionState { ready, loadingModel, noModel, error }
enum MessageSender { user, ai }
enum MessageStatus { sending, sent, error }

/// Formato de chat template que usa cada familia de modelos.
/// Los GGUF de Qwen usan `<|im_start|>/<|im_end|>` (ChatML-like).
/// Los GGUF de DeepSeek-R1 usan `<｜begin▁of▁sentence｜>/<｜end▁of▁sentence｜>`.
enum ChatTemplate { qwen, deepseek }

class ChatMessage {
  final String id; final MessageSender sender; final String text; final DateTime timestamp; final double? tps; final MessageStatus status;
  const ChatMessage({required this.id, required this.sender, required this.text, required this.timestamp, this.tps, this.status = MessageStatus.sent});

  Map<String, dynamic> toJson() => {
    'id': id, 'sender': sender.name, 'text': text,
    'timestamp': timestamp.toIso8601String(), 'tps': tps, 'status': status.name,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    sender: MessageSender.values.byName(json['sender'] as String),
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    tps: (json['tps'] as num?)?.toDouble(),
    status: MessageStatus.values.byName(json['status'] as String),
  );
}

class ChatState {
  final List<ChatMessage> messages; final String input; final bool generating; final String activeModel; final ModelConnectionState connection; final List<String> availableModels; final bool showModelSelector; final bool engineOnline; final double? liveTps;
  /// Texto parcial de la generación streaming en curso. Vacío si no hay
  /// generación activa o si aún no llegó el primer token.
  final String streamingText;
  const ChatState({this.messages = const [], this.input = '', this.generating = false, this.activeModel = 'Sin modelo', this.connection = ModelConnectionState.noModel, this.availableModels = const [], this.showModelSelector = false, this.engineOnline = false, this.liveTps, this.streamingText = ''});

  ChatState copyWith({List<ChatMessage>? messages, String? input, bool? generating, String? activeModel, ModelConnectionState? connection, List<String>? availableModels, bool? showModelSelector, bool? engineOnline, double? liveTps, String? streamingText}) =>
    ChatState(messages: messages ?? this.messages, input: input ?? this.input, generating: generating ?? this.generating, activeModel: activeModel ?? this.activeModel, connection: connection ?? this.connection, availableModels: availableModels ?? this.availableModels, showModelSelector: showModelSelector ?? this.showModelSelector, engineOnline: engineOnline ?? this.engineOnline, liveTps: liveTps ?? this.liveTps, streamingText: streamingText ?? this.streamingText);
}

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

  /// Número máximo de mensajes enviados al motor como historial (40 = ~20 turnos).
  /// Los modelos GGUF pequeños (1B-7B) tienen ventanas de contexto limitadas
  /// (8K-32K tokens). 40 mensajes mantienen el prompt bajo ~4K tokens en uso típico.
  static const int _maxHistoryMessages = 40;

  /// System prompt inyectado al inicio de cada conversación multi-turno.
  /// Define el comportamiento base del asistente para todos los modelos.
  static const String _systemPrompt = 'Eres NanoAI, un asistente que corre 100% '
      'en el dispositivo, sin conexión a internet. Responde de forma concisa, '
      'técnica y útil. Si no sabes algo, dilo con honestidad.';

  ChatNotifier(this._ref) : super(ChatState(availableModels: [for (final m in NeuralCatalog.models) m.name])) { _restoreModel(); _restoreMessages(); }

  /// Restaura la última selección de modelo para que sobreviva al reinicio.
  Future<void> _restoreModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('nanoai_active_model');
      if (saved == null || saved.isEmpty) return;
      if (!mounted) return;
      state = state.copyWith(activeModel: saved, connection: ModelConnectionState.loadingModel);
      await _checkEngine(saved);
    } catch (_) { /* persistencia no disponible: seguir con default */ }
  }

  /// Clave en SharedPreferences para el historial de chat.
  static const String _historyKey = 'nanoai_chat_history';

  /// Persiste los mensajes actuales en SharedPreferences como JSON.
  Future<void> _persistMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.messages.map((m) => m.toJson()).toList());
      await prefs.setString(_historyKey, json);
    } catch (_) { /* sin persistencia: no bloquea */ }
  }

  /// Carga el historial desde SharedPreferences. Solo se llama durante init
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
    } catch (_) { /* datos corruptos o no disponibles: ignorar */ }
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
    final userMsg = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.user, text: t, timestamp: DateTime.now());
    state = state.copyWith(messages: [...state.messages, userMsg], input: '', generating: true, streamingText: '');
    _persistMessages(); // guardar el user msg inmediatamente: si la app crashea antes de que el motor responda, no se pierde
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
  ///   <|im_start|>system\n...<|im_end|>\n
  ///   <|im_start|>user\n...<|im_end|>\n
  ///   <|im_start|>assistant\n...<|im_end|>\n
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
  ///   <｜begin▁of▁sentence｜>system\n...\n<｜end▁of▁sentence｜>\n
  ///   <｜begin▁of▁sentence｜>user\n...\n<｜end▁of▁sentence｜>\n
  ///   <｜begin▁of▁sentence｜>assistant\n...\n<｜end▁of▁sentence｜>\n
  String _buildDeepSeekPrompt(List<ChatMessage> history, String newUserText) {
    // Tokens especiales native de DeepSeek-R1. Son secuencias multi-carácter que
    // el tokenizer del modelo mapea a un solo ID si el GGUF los define.
    const bos = '<｜begin▁of▁sentence｜>';
    const eos = '<｜end▁of▁sentence｜>';
    final buffer = StringBuffer();
    buffer.write('${bos}system\n$_systemPrompt\n$eos\n');
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.write('$bos$role\n${msg.text}\n$eos\n');
    }
    buffer.write('${bos}user\n$newUserText\n$eos\n');
    buffer.write('${bos}assistant\n');
    return buffer.toString();
  }

  Future<void> _generate(String text) async {
    _generationCancelled = false;
    // Prompt multi-turno: el historial YA incluye el mensaje del usuario recién
    // enviado (añadido en send()). Lo excluimos del historial para evitar
    // duplicarlo — el último mensaje se pasa explícitamente como newUserText.
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : <ChatMessage>[];
    final prompt = _buildChatPrompt(history, text);

    // Streaming: cada token actualiza streamingText en tiempo real.
    // Al finalizar (stop: true), el texto acumulado se convierte en ChatMessage.
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
        // Actualizar texto parcial en vivo para que la UI lo renderice.
        if (mounted) {
          state = state.copyWith(streamingText: buffer.toString());
        }
      }

      // Si el usuario canceló mientras el motor terminaba (stop token llegó
      // justo cuando se pulsó Stop), descartamos la respuesta.
      if (_generationCancelled || !mounted) return;

      final fullText = buffer.toString().trim();
      if (fullText.isEmpty) {
        // El motor respondió con stream vacío (raro pero posible con modelos
        // muy pequeños o prompts que confunden al tokenizer). Dejamos constancia.
        final emptyMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: '(sin respuesta)',
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        );
        state = state.copyWith(
          messages: [...state.messages, emptyMsg],
          generating: false, streamingText: '',
          connection: ModelConnectionState.ready, engineOnline: true,
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
      _persistMessages(); // guardar historial completo tras respuesta exitosa
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
      _persistMessages(); // persistir incluso en error: el usuario espera ver el mensaje tras reiniciar
    } finally {
      _streamClient = null;
    }
  }

  // STOP cancela la respuesta PENDIENTE: cierra la conexión HTTP del stream
  // y marca cancellation para que el bucle de tokens descarte lo que llegue.
  void stop() {
    _generationCancelled = true;
    _streamClient?.close();
    _streamClient = null;
    state = state.copyWith(generating: false, streamingText: '');
    _persistMessages(); // guardar lo que haya (incluye el mensaje del usuario)
  }
  void clear() async {
    // Vaciar mensajes ANTES de cancelar la generación. Así, si stop()
    // dispara _persistMessages(), captura la lista vacía y no resucita
    // mensajes viejos después de que remove(_historyKey) los borre.
    state = state.copyWith(messages: [], input: '');
    if (state.generating) stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) { /* sin persistencia: no bloquea */ }
  }
  void delete(String id) {
    state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
    _persistMessages();
  }
  /// Reintenta el envío tras un error: elimina tanto el mensaje de error
  /// como el mensaje del usuario que lo precedía, luego reenvía el texto
  /// original limpio (evita duplicar el user msg en el prompt multi-turno).
  void retry(String errorMessageId) {
    // Si ya hay una generación en curso, no hacer nada.
    // Eliminar mensajes + send() fallido = pérdida de datos.
    if (state.generating) return;
    final msgs = state.messages;
    final errIdx = msgs.indexWhere((m) => m.id == errorMessageId);
    if (errIdx < 1) return; // necesita un mensaje de usuario antes
    final userMsg = msgs[errIdx - 1];
    if (userMsg.sender != MessageSender.user) return;
    // Eliminar AMBOS: el error y el mensaje del usuario que lo originó.
    // send() añadirá un nuevo user msg limpio.
    final newMsgs = msgs.where((m) => m.id != errorMessageId && m.id != userMsg.id).toList();
    state = state.copyWith(messages: newMsgs);
    _persistMessages();
    // Reenviar el texto original
    send(userMsg.text);
  }
  void toggleSelector() => state = state.copyWith(showModelSelector: !state.showModelSelector);

  void selectModel(String name) {
    // Nota: SELinux impide que la app rearranque el motor per-selección.
    // Esta selección persiste el modelo; el server real sigue sirviendo el
    // .gguf que fue lanzado por adb. Comprobamos /health igualmente.
    state = state.copyWith(activeModel: name, connection: ModelConnectionState.loadingModel, showModelSelector: false);
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(milliseconds: 600), () async {
      _loadTimer = null;
      await _checkEngine(name);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nanoai_active_model', name);
      } catch (_) { /* sin persistencia: no bloquea */ }
    });
  }

  @override void dispose() { _streamClient?.close(); _loadTimer?.cancel(); _engine.dispose(); super.dispose(); }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));

// ─── Dashboard Metrics (real hardware via MethodChannel) ───
class DashboardState {
  final double ramFreeGb, ramTotalGb, ramProgress, tempC, tempProgress, batteryPct, tpsValue, tpsProgress;
  final double storageTotalGb, storageFreeGb, storageProgress;
  final bool isCharging;
  final int cpuCores;
  final bool isLive; // true = connected to real device

  const DashboardState({
    this.ramFreeGb = 0, this.ramTotalGb = 0, this.ramProgress = 0,
    this.tempC = 0, this.tempProgress = 0,
    this.batteryPct = -1, this.tpsValue = 0, this.tpsProgress = 0,
    this.storageTotalGb = 0, this.storageFreeGb = 0, this.storageProgress = 0,
    this.isCharging = false, this.cpuCores = 0, this.isLive = false,
  });
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  Timer? _timer;
  final Ref _ref;

  DashboardNotifier(this._ref) : super(const DashboardState()) { _startPolling(); }

  void _startPolling() {
    // Fire immediately
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    final d = await DeviceMetrics.fetch();
    // TPS real del motor: lo reporta ChatNotifier tras cada generación.
    final liveTps = _ref.read(chatProvider).liveTps;
    state = DashboardState(
      ramFreeGb: d.ramAvailableGb,
      ramTotalGb: d.ramTotalGb,
      ramProgress: d.ramProgress,
      tempC: d.cpuTempC ?? 0,
      tempProgress: d.cpuTempC != null ? d.cpuTempC! / 90.0 : 0,
      batteryPct: d.batteryPct,
      isCharging: d.isCharging,
      tpsValue: liveTps ?? 0,
      tpsProgress: liveTps != null ? (liveTps / 40.0).clamp(0.0, 1.0) : 0,
      storageTotalGb: d.storageTotalGb,
      storageFreeGb: d.storageFreeGb,
      storageProgress: d.storageProgress,
      cpuCores: d.cpuCores,
      isLive: d.ramTotalMb > 0,
    );
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) => DashboardNotifier(ref));

// ─── Models State ───
class ModelsState {
  final List<ModelItem> models; final String query; final String? quantFilter;
  const ModelsState({this.models = const [], this.query = '', this.quantFilter});
}

class ModelItem {
  final String id, name, params, quant, desc; final double sizeGb, ramGb; final bool downloaded; final bool active; final bool loading;
  const ModelItem({required this.id, required this.name, required this.params, required this.quant, required this.sizeGb, required this.ramGb, required this.downloaded, required this.active, required this.desc, this.loading = false});
}

class ModelsNotifier extends StateNotifier<ModelsState> {
  final Ref _ref;
  ModelsNotifier(this._ref) : super(ModelsState(models: [
    for (final (i, m) in NeuralCatalog.models.indexed)
      ModelItem(id: 'm$i', name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: true, active: false, desc: _descFor(m.name), loading: false),
  ]));

  /// Descripciones honestas por modelo: un solo server corre por vez y
  /// cambiarlo requiere adb/reinicio (restricción SELinux del device).
  static String _descFor(String name) => switch (name) {
    'Qwen2.5-1.1B-Instruct' => 'Ligero y rápido, ideal para CPU móvil. Carga por defecto.',
    'Qwen2.5-3B-Instruct' => 'Mejor calidad de 3B: tarda más pero responde mejor.',
    'DeepSeek-R1-7B' => 'Razonamiento profundo. Requiere adb para cargarse.',
    'DeepSeek-R1-7B-Q2' => 'Variante Q2_K del 7B: menor RAM, calidad reducida.',
    _ => 'Cuántización y tamaño reales desplegados en el dispositivo.',
  };

  void setQuery(String q) => state = ModelsState(models: state.models, query: q, quantFilter: state.quantFilter);
  void setFilter(String? f) => state = ModelsState(models: state.models, query: state.query, quantFilter: f);

  /// Carga un modelo: delega en ChatNotifier.selectModel() que hace el health
  /// check real y persiste la selección. El estado de carga se refleja vía
  /// [chatProvider] — sin barras de progreso simuladas.
  void loadModel(String id) {
    final item = state.models.firstWhere((m) => m.id == id);
    // Marcar loading en ModelsState mientras el ChatNotifier verifica el motor.
    state = ModelsState(models: state.models.map((m) => ModelItem(id: m.id, name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: m.downloaded, active: m.id == id, desc: m.desc, loading: m.id == id)).toList(), query: state.query, quantFilter: state.quantFilter);
    // Delegar la selección real al ChatNotifier (health check + persistencia).
    _ref.read(chatProvider.notifier).selectModel(item.name);
  }
}

final modelsProvider = StateNotifierProvider<ModelsNotifier, ModelsState>((ref) => ModelsNotifier(ref));

// ─── Rootfs global (compartido) ───
/// Único RootfsManager de la app: main.dart lo usa para el auto-bootstrap
/// al arrancar, y el terminal lo reusa (vía ShellExecutor) para que la
/// instalación no se duplique y el estado esté sincronizado.
final rootfsProvider = Provider<RootfsManager>((ref) => RootfsManager.instance);
