import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ================================================================
// Settings Repository (real persistence)
// ================================================================

class SettingsRepository {
  static const _k = 'nanoai_settings';
  late SharedPreferences _prefs;
  bool _ready = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  Future<SettingsState> load() async {
    if (!_ready) {
      // Lazy-init: si la app nunca llamó init() (p. ej. se abre directo el
      // visor VNC sin pasar por Ajustes), cargar igual — antes devolvía
      // defaults y la persistencia (tema, password VNC) se perdía en cada
      // arranque en frío.
      await init();
    }
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
        vncPassword: m['vncPassword'] as String? ?? '',
      );
    } catch (_) {
      return const SettingsState();
    }
  }

  Future<void> save(SettingsState s) async {
    if (!_ready) await init();
    await _prefs.setString(_k, jsonEncode({
      'themeMode': s.themeMode,
      'temperature': s.temperature,
      'topP': s.topP,
      'madvise': s.madvise,
      'oomGuard': s.oomGuard,
      'thermalLimit': s.thermalLimit,
      'batteryMode': s.batteryMode,
      'maxTokens': s.maxTokens,
      'vncPassword': s.vncPassword,
    }));
  }
}

final settingsRepoProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

// ================================================================
// Settings State (identical to before but with persistence)
// ================================================================

class SettingsState {
  final String themeMode;
  final double temperature, topP;
  final bool madvise, oomGuard;
  final double thermalLimit;
  final String batteryMode;
  /// Tokens máximos que el motor generará por respuesta. 512 por defecto.
  final int maxTokens;
  /// Contraseña de protección VNC del escritorio Linux (vacío = desactivada).
  /// Máximo 8 bytes efectivos (límite del protocolo VNC).
  final String vncPassword;

  const SettingsState({
    this.themeMode = 'Sistema',
    this.temperature = 0.7,
    this.topP = 0.9,
    this.madvise = true,
    this.oomGuard = true,
    this.thermalLimit = 42,
    this.batteryMode = 'Balanced',
    this.maxTokens = 512,
    this.vncPassword = '',
  });

  SettingsState copyWith({
    String? themeMode,
    double? temperature,
    double? topP,
    bool? madvise,
    bool? oomGuard,
    double? thermalLimit,
    String? batteryMode,
    int? maxTokens,
    String? vncPassword,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        madvise: madvise ?? this.madvise,
        oomGuard: oomGuard ?? this.oomGuard,
        thermalLimit: thermalLimit ?? this.thermalLimit,
        batteryMode: batteryMode ?? this.batteryMode,
        maxTokens: maxTokens ?? this.maxTokens,
        vncPassword: vncPassword ?? this.vncPassword,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;
  final Ref _ref;

  SettingsNotifier(this._repo, this._ref) : super(const SettingsState());

  Future<void> init() async {
    await _repo.init();
    state = await _repo.load();
    // Sync theme to themeModeProvider
    _ref.read(themeModeProvider.notifier).state = state.themeMode == 'Oscuro'
        ? ThemeMode.dark
        : state.themeMode == 'Claro'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  Future<void> _lastWrite = Future<void>.value();

  /// P2: antes cada setter lanzaba un save() en paralelo — una ráfaga de
  /// sliders (temperatura, thermalLimit) intercalaba writes y podía persistir
  /// un estado viejo como último. Cola FIFO: cada write espera al anterior.
  /// El try/catch es deliberado: persistencia es best-effort, el estado en
  /// memoria ya es la fuente de verdad de la sesión y un fallo de disco no
  /// debe romper la cadena de writes ni crashear la UI.
  Future<void> _persist(SettingsState s) {
    state = s;
    final write = _lastWrite.then((_) async {
      try {
        await _repo.save(s);
      } catch (_) {}
    });
    _lastWrite = write;
    return write;
  }

  void setThemeMode(String m) {
    _persist(state.copyWith(themeMode: m));
    _ref.read(themeModeProvider.notifier).state = m == 'Oscuro'
        ? ThemeMode.dark
        : m == 'Claro'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  void setTemperature(double v) => _persist(state.copyWith(temperature: v));
  void setTopP(double v) => _persist(state.copyWith(topP: v));
  void toggleMadvise(bool v) => _persist(state.copyWith(madvise: v));
  void toggleOom(bool v) => _persist(state.copyWith(oomGuard: v));
  void setThermalLimit(double v) => _persist(state.copyWith(thermalLimit: v));
  void setBatteryMode(String v) => _persist(state.copyWith(batteryMode: v));
  void setMaxTokens(int v) => _persist(state.copyWith(maxTokens: v));

  /// Activa/desactiva la protección VNC del escritorio. Vacío = sin auth.
  void setVncPassword(String v) => _persist(state.copyWith(vncPassword: v));
}

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.read(settingsRepoProvider), ref),
);
