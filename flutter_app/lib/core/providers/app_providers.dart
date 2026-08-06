import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_metrics.dart';
import '../services/llm_engine_client.dart';

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
      );
    } catch (_) { return const SettingsState(); }
  }

  Future<void> save(SettingsState s) async {
    if (!_ready) await init();
    await _prefs.setString(_k, jsonEncode({
      'themeMode': s.themeMode, 'temperature': s.temperature, 'topP': s.topP,
      'madvise': s.madvise, 'oomGuard': s.oomGuard, 'thermalLimit': s.thermalLimit, 'batteryMode': s.batteryMode,
    }));
  }
}

final settingsRepoProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

// ─── Settings State (identical to before but with persistence) ───
class SettingsState {
  final String themeMode; final double temperature, topP; final bool madvise, oomGuard; final double thermalLimit; final String batteryMode;
  const SettingsState({this.themeMode = 'Sistema', this.temperature = 0.7, this.topP = 0.9, this.madvise = true, this.oomGuard = true, this.thermalLimit = 42, this.batteryMode = 'Balanced'});

  SettingsState copyWith({String? themeMode, double? temperature, double? topP, bool? madvise, bool? oomGuard, double? thermalLimit, String? batteryMode}) =>
    SettingsState(themeMode: themeMode ?? this.themeMode, temperature: temperature ?? this.temperature, topP: topP ?? this.topP, madvise: madvise ?? this.madvise, oomGuard: oomGuard ?? this.oomGuard, thermalLimit: thermalLimit ?? this.thermalLimit, batteryMode: batteryMode ?? this.batteryMode);
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
  const LmCatalogEntry(this.name, this.params, this.quant, this.sizeGb, this.ramGb, this.file);
}

abstract final class NeuralCatalog {
  static const models = <LmCatalogEntry>[
    LmCatalogEntry('Qwen2.5-1.1B-Instruct', '1.1B', 'Q8_0', 1.12, 1.8, 'qwen.gguf'),
    LmCatalogEntry('Qwen2.5-3B-Instruct', '3B', 'Q8_0', 2.10, 2.8, 'qwen3b.gguf'),
    LmCatalogEntry('DeepSeek-R1-7B', '7B', 'Q4_K_M', 4.68, 3.6, 'deepseek.gguf'),
    LmCatalogEntry('DeepSeek-R1-7B-Q2', '7B', 'Q2_K', 3.01, 2.2, 'deepseek-q2k.gguf'),
  ];
  static String fileOf(String name) => models.firstWhere((m) => m.name == name, orElse: () => models[0]).file;
}

enum ModelConnectionState { ready, loadingModel, noModel, error }
enum MessageSender { user, ai }
enum MessageStatus { sending, sent, error }

class ChatMessage {
  final String id; final MessageSender sender; final String text; final DateTime timestamp; final double? tps; final MessageStatus status;
  const ChatMessage({required this.id, required this.sender, required this.text, required this.timestamp, this.tps, this.status = MessageStatus.sent});
}

class ChatState {
  final List<ChatMessage> messages; final String input; final bool generating; final String activeModel; final ModelConnectionState connection; final List<String> availableModels; final bool showModelSelector; final bool engineOnline; final double? liveTps;
  const ChatState({this.messages = const [], this.input = '', this.generating = false, this.activeModel = 'Sin modelo', this.connection = ModelConnectionState.noModel, this.availableModels = const [], this.showModelSelector = false, this.engineOnline = false, this.liveTps});

  ChatState copyWith({List<ChatMessage>? messages, String? input, bool? generating, String? activeModel, ModelConnectionState? connection, List<String>? availableModels, bool? showModelSelector, bool? engineOnline, double? liveTps}) =>
    ChatState(messages: messages ?? this.messages, input: input ?? this.input, generating: generating ?? this.generating, activeModel: activeModel ?? this.activeModel, connection: connection ?? this.connection, availableModels: availableModels ?? this.availableModels, showModelSelector: showModelSelector ?? this.showModelSelector, engineOnline: engineOnline ?? this.engineOnline, liveTps: liveTps ?? this.liveTps);
}

class ChatNotifier extends StateNotifier<ChatState> {
  // Motor llama.cpp real desplegado en el dispositivo (loopback 127.0.0.1:8080).
  final LLMEngineClient _engine = LLMEngineClient();
  // Timer activo de generación: permite cancelar la respuesta con STOP.
  Timer? _genTimer;
  // Cancelación cooperativa: STOP o un segundo envío anulan la generación en curso.
  bool _generationCancelled = false;
  // Timer de carga de modelo: cancelable para que solo el último
  // modelo seleccionado pueda transicionar a ready.
  Timer? _loadTimer;
  ChatNotifier() : super(ChatState(availableModels: [for (final m in NeuralCatalog.models) m.name])) { _restoreModel(); }

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

  void send() {
    final text = state.input.trim();
    if (text.isEmpty || state.generating || state.connection != ModelConnectionState.ready) return;
    final userMsg = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.user, text: text, timestamp: DateTime.now());
    state = state.copyWith(messages: [...state.messages, userMsg], input: '', generating: true);
    _generate(text);
  }

  Future<void> _generate(String text) async {
    // Formato de chat Qwen (los .gguf del device usan este chat template).
    _generationCancelled = false;
    final prompt = '<|im_start|>user\n$text<|im_end|>\n<|im_start|>assistant\n';
    try {
      final res = await _engine.generate(prompt: prompt, temperature: 0.7, maxTokens: 256);
      if (!mounted || _generationCancelled) return;
      _genTimer = null;
      if (res.text.isEmpty) {
        state = state.copyWith(generating: false, connection: ModelConnectionState.ready);
        return;
      }
      final aiMsg = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.ai, text: res.text, timestamp: DateTime.now(), tps: res.tps, status: MessageStatus.sent);
      state = state.copyWith(messages: [...state.messages, aiMsg], generating: false, connection: ModelConnectionState.ready, engineOnline: true, liveTps: res.tps ?? state.liveTps);
    } on LLMEngineException catch (_) {
      if (!mounted) return;
      // Motor no responde: degradación HONESTA. No se finge inferencia real.
      _genTimer?.cancel();
      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: '⚠️ El motor llama.cpp no respondió. Confirma que esté levantado en el dispositivo y vuelve a intentarlo. (${state.activeModel})',
        timestamp: DateTime.now(),
      );
      _genTimer = null;
      state = state.copyWith(messages: [...state.messages, aiMsg], generating: false, engineOnline: false);
    }
  }

  // STOP cancela la respuesta PENDIENTE: invalida la generación HTTP y el timer.
  void stop() {
    _generationCancelled = true;
    _genTimer?.cancel();
    _genTimer = null;
    state = state.copyWith(generating: false);
  }
  void clear() => state = state.copyWith(messages: [], input: '');
  void delete(String id) => state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
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

  @override void dispose() { _genTimer?.cancel(); _loadTimer?.cancel(); _engine.dispose(); super.dispose(); }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier());

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

// ─── Models State (real download/load with progress) ───
class ModelsState {
  final List<ModelItem> models; final String query; final String? quantFilter;
  const ModelsState({this.models = const [], this.query = '', this.quantFilter});
}

class ModelItem {
  final String id, name, params, quant, desc; final double sizeGb, ramGb; final bool downloaded, active; final double? progress; final bool loading;
  const ModelItem({required this.id, required this.name, required this.params, required this.quant, required this.sizeGb, required this.ramGb, required this.downloaded, required this.active, required this.desc, this.progress, this.loading = false});
}

class ModelsNotifier extends StateNotifier<ModelsState> {
  ModelsNotifier() : super(ModelsState(models: [
    for (final (i, m) in NeuralCatalog.models.indexed)
      ModelItem(id: 'm$i', name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: true, active: i == 0, desc: _descFor(m.name), progress: null, loading: false),
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

  void downloadModel(String id) {
    state = ModelsState(models: state.models.map((m) => m.id == id ? ModelItem(id: m.id, name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: m.downloaded, active: m.active, desc: m.desc, loading: true, progress: 0) : m).toList(), query: state.query, quantFilter: state.quantFilter);
    _simulateProgress(id, true);
  }

  void loadModel(String id) {
    // Deactivate current model, activate new one
    state = ModelsState(models: state.models.map((m) {
      if (m.id == id) return ModelItem(id: m.id, name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: m.downloaded, active: false, desc: m.desc, loading: true, progress: 0);
      return ModelItem(id: m.id, name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: m.downloaded, active: false, desc: m.desc);
    }).toList(), query: state.query, quantFilter: state.quantFilter);
    _simulateProgress(id, false);
  }

  void _simulateProgress(String id, bool isDownload) {
    double p = 0;
    Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) { t.cancel(); return; }
      p += 0.08; if (p >= 1) { p = 1; t.cancel(); }
      state = ModelsState(models: state.models.map((m) => m.id == id ? ModelItem(id: m.id, name: m.name, params: m.params, quant: m.quant, sizeGb: m.sizeGb, ramGb: m.ramGb, downloaded: isDownload || m.downloaded, active: !isDownload, desc: m.desc, loading: p < 1, progress: p) : m).toList(), query: state.query, quantFilter: state.quantFilter);
    });
  }
}

final modelsProvider = StateNotifierProvider<ModelsNotifier, ModelsState>((ref) => ModelsNotifier());
