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

  const SettingsState({
    this.themeMode = 'Sistema',
    this.temperature = 0.7,
    this.topP = 0.9,
    this.madvise = true,
    this.oomGuard = true,
    this.thermalLimit = 42,
    this.batteryMode = 'Balanced',
    this.maxTokens = 512,
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
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;
  final Ref _ref;

  SettingsNotifier(this._repo, this._ref) : super(const SettingsState());

  Future<void> init() async {
    await _repo.init();
    state = _repo.load();
    // Sync theme to themeModeProvider
    _ref.read(themeModeProvider.notifier).state = state.themeMode == 'Oscuro'
        ? ThemeMode.dark
        : state.themeMode == 'Claro'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  Future<void> _persist(SettingsState s) async {
    state = s;
    await _repo.save(s);
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
}

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.read(settingsRepoProvider), ref),
);
