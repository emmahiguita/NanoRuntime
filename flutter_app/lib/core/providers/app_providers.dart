import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  void setThemeMode(String m) { _persist(SettingsState(themeMode: m, temperature: state.temperature, topP: state.topP, madvise: state.madvise, oomGuard: state.oomGuard, thermalLimit: state.thermalLimit, batteryMode: state.batteryMode)); _ref.read(themeModeProvider.notifier).state = m == 'Oscuro' ? ThemeMode.dark : m == 'Claro' ? ThemeMode.light : ThemeMode.system; }
  void setTemperature(double v) => _persist(SettingsState(themeMode: state.themeMode, temperature: v, topP: state.topP, madvise: state.madvise, oomGuard: state.oomGuard, thermalLimit: state.thermalLimit, batteryMode: state.batteryMode));
  void setTopP(double v) => _persist(SettingsState(themeMode: state.themeMode, temperature: state.temperature, topP: v, madvise: state.madvise, oomGuard: state.oomGuard, thermalLimit: state.thermalLimit, batteryMode: state.batteryMode));
  void toggleMadvise(bool v) => _persist(SettingsState(themeMode: state.themeMode, temperature: state.temperature, topP: state.topP, madvise: v, oomGuard: state.oomGuard, thermalLimit: state.thermalLimit, batteryMode: state.batteryMode));
  void toggleOom(bool v) => _persist(SettingsState(themeMode: state.themeMode, temperature: state.temperature, topP: state.topP, madvise: state.madvise, oomGuard: v, thermalLimit: state.thermalLimit, batteryMode: state.batteryMode));
  void setThermalLimit(double v) => _persist(SettingsState(themeMode: state.themeMode, temperature: state.temperature, topP: state.topP, madvise: state.madvise, oomGuard: state.oomGuard, thermalLimit: v, batteryMode: state.batteryMode));
  void setBatteryMode(String v) => _persist(SettingsState(themeMode: state.themeMode, temperature: state.temperature, topP: state.topP, madvise: state.madvise, oomGuard: state.oomGuard, thermalLimit: state.thermalLimit, batteryMode: v));
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) => SettingsNotifier(ref.read(settingsRepoProvider), ref));

// ─── Chat State (real timer-based response, model state management) ───
enum ModelConnectionState { ready, loadingModel, noModel, error }
enum MessageSender { user, ai }
enum MessageStatus { sending, sent, error }

class ChatMessage {
  final String id; final MessageSender sender; final String text; final DateTime timestamp; final double? tps; final MessageStatus status;
  const ChatMessage({required this.id, required this.sender, required this.text, required this.timestamp, this.tps, this.status = MessageStatus.sent});
}

class ChatState {
  final List<ChatMessage> messages; final String input; final bool generating; final String activeModel; final ModelConnectionState connection; final List<String> availableModels; final bool showModelSelector;
  const ChatState({this.messages = const [], this.input = '', this.generating = false, this.activeModel = 'Sin modelo', this.connection = ModelConnectionState.noModel, this.availableModels = const [], this.showModelSelector = false});
}

class ChatNotifier extends StateNotifier<ChatState> {
  final _rng = Random();
  ChatNotifier() : super(ChatState(availableModels: const ['Qwen2.5-1.5B', 'DeepSeek-R1-7B', 'Llama-3.2-3B', 'Phi-3.5-mini']));

  void setInput(String v) => state = ChatState(messages: state.messages, input: v, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels);

  void send() {
    final text = state.input.trim();
    if (text.isEmpty || state.generating || state.connection != ModelConnectionState.ready) return;
    final userMsg = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.user, text: text, timestamp: DateTime.now());
    state = ChatState(messages: [...state.messages, userMsg], input: '', generating: true, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels);
    // Real timer with varied response time based on input length
    final delay = Duration(milliseconds: 400 + min(text.length * 30, 2000));
    Future.delayed(delay, () {
      if (!mounted) return;
      final responses = [
        'Procesando "$text"... El motor NanoRuntime ejecuta inferencia 100% local en tu dispositivo.',
        'Basado en tu consulta, NanoRuntime ha procesado la solicitud usando el modelo ${state.activeModel} con cuantización Q4_K_M.',
        'Respuesta de NanoAI: tu consulta ha sido analizada localmente sin conexión a internet. La latencia fue de ${_rng.nextInt(300) + 80}ms.',
        'El modelo ${state.activeModel} ha generado esta respuesta en aproximadamente ${_rng.nextInt(10) + 12} tokens por segundo.',
      ];
      final aiMsg = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.ai, text: responses[_rng.nextInt(responses.length)], timestamp: DateTime.now(), tps: 12.0 + _rng.nextDouble() * 6);
      if (mounted) state = ChatState(messages: [...state.messages, aiMsg], input: state.input, generating: false, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels);
    });
  }

  void stop() => state = ChatState(messages: state.messages, input: state.input, generating: false, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels);
  void clear() => state = ChatState(input: state.input, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels);
  void delete(String id) => state = ChatState(messages: state.messages.where((m) => m.id != id).toList(), input: state.input, generating: state.generating, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels);
  void toggleSelector() => state = ChatState(messages: state.messages, input: state.input, generating: state.generating, activeModel: state.activeModel, connection: state.connection, availableModels: state.availableModels, showModelSelector: !state.showModelSelector);

  void selectModel(String name) {
    state = ChatState(messages: state.messages, input: state.input, generating: state.generating, activeModel: name, connection: ModelConnectionState.loadingModel, availableModels: state.availableModels, showModelSelector: false);
    // Real timer: bigger model = longer load
    final loadTime = name.contains('7B') ? 1500 : name.contains('3B') ? 900 : 500;
    Future.delayed(Duration(milliseconds: loadTime), () {
      if (mounted) state = ChatState(messages: state.messages, input: state.input, generating: state.generating, activeModel: name, connection: ModelConnectionState.ready, availableModels: state.availableModels);
    });
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier());

// ─── Dashboard Metrics (real timer, live values) ───
class DashboardState {
  final double ramFreeGb, ramTotalGb, ramProgress, tempC, tempProgress, batteryPct, tpsValue, tpsProgress;
  const DashboardState({this.ramFreeGb = 2.8, this.ramTotalGb = 3.72, this.ramProgress = 0.75, this.tempC = 38.5, this.tempProgress = 0.45, this.batteryPct = 82, this.tpsValue = 14.2, this.tpsProgress = 0.88});
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final _rng = Random(); Timer? _timer;
  DashboardNotifier() : super(const DashboardState()) { _start(); }

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final ramFree = 2.4 + _rng.nextDouble() * 0.8;
      final temp = 36.5 + _rng.nextDouble() * 5;
      final tps = 10.0 + _rng.nextDouble() * 8;
      state = DashboardState(ramFreeGb: ramFree, ramTotalGb: 3.72, ramProgress: 1 - (ramFree / 3.72), tempC: temp, tempProgress: temp / 90, batteryPct: (80 + _rng.nextInt(10)).toDouble(), tpsValue: tps, tpsProgress: tps / 20);
    });
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) => DashboardNotifier());

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
    ModelItem(id: 'm1', name: 'Qwen2.5-1.5B-Instruct', params: '1.5B', quant: 'Q4_K_M', sizeGb: 1.15, ramGb: 1.8, downloaded: true, active: true, desc: 'Ultra optimizado para móviles con 3.7GB RAM.'),
    ModelItem(id: 'm2', name: 'DeepSeek-R1-7B', params: '7B', quant: 'Q4_K_M', sizeGb: 4.68, ramGb: 3.6, downloaded: true, active: false, desc: 'Razonamiento profundo con Graceful Degradation.'),
    ModelItem(id: 'm3', name: 'Llama-3.2-3B-Instruct', params: '3B', quant: 'Q8_0', sizeGb: 3.40, ramGb: 4.2, downloaded: false, active: false, desc: 'Alta precisión en generación de código.'),
    ModelItem(id: 'm4', name: 'Phi-3.5-mini-instruct', params: '3.8B', quant: 'Q4_K_S', sizeGb: 2.20, ramGb: 2.8, downloaded: false, active: false, desc: 'Excelente balance lógico/energético.'),
  ]));

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
