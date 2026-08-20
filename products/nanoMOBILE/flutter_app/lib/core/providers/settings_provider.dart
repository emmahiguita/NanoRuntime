import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';

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
        maxTokens: (m['maxTokens'] as num?)?.toInt() ?? 2048,
        vncPassword: m['vncPassword'] as String? ?? '',
        desktopMobileMode: m['desktopMobileMode'] as bool? ?? false,
        agentAutomationMode: AgentAutomationMode.fromName(
          m['agentAutomationMode'] as String?,
        ),
      );
    } catch (_) {
      return const SettingsState();
    }
  }

  Future<void> save(SettingsState s) async {
    if (!_ready) await init();
    await _prefs.setString(
      _k,
      jsonEncode({
        'themeMode': s.themeMode,
        'temperature': s.temperature,
        'topP': s.topP,
        'maxTokens': s.maxTokens,
        'vncPassword': s.vncPassword,
        'desktopMobileMode': s.desktopMobileMode,
        'agentAutomationMode': s.agentAutomationMode.name,
      }),
    );
  }
}

final settingsRepoProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

class SettingsState {
  final String themeMode;
  final double temperature, topP;
  final int maxTokens;
  final String vncPassword;
  final bool desktopMobileMode;
  final AgentAutomationMode agentAutomationMode;

  const SettingsState({
    this.themeMode = 'Sistema',
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 2048,
    this.vncPassword = '',
    this.desktopMobileMode = false,
    this.agentAutomationMode = AgentAutomationMode.assisted,
  });

  SettingsState copyWith({
    String? themeMode,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? vncPassword,
    bool? desktopMobileMode,
    AgentAutomationMode? agentAutomationMode,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    temperature: temperature ?? this.temperature,
    topP: topP ?? this.topP,
    maxTokens: maxTokens ?? this.maxTokens,
    vncPassword: vncPassword ?? this.vncPassword,
    desktopMobileMode: desktopMobileMode ?? this.desktopMobileMode,
    agentAutomationMode: agentAutomationMode ?? this.agentAutomationMode,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo) : super(const SettingsState());

  Future<void> init() async {
    await _repo.init();
    state = await _repo.load();
    // themeModeProvider ahora es derivado y se sincroniza automáticamente
  }

  Future<void> _lastWrite = Future<void>.value();

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
    // themeModeProvider ahora es derivado y se sincroniza automáticamente
  }

  void setTemperature(double v) => _persist(state.copyWith(temperature: v));
  void setTopP(double v) => _persist(state.copyWith(topP: v));
  void setMaxTokens(int v) => _persist(state.copyWith(maxTokens: v));
  void setVncPassword(String v) => _persist(state.copyWith(vncPassword: v));
  void setDesktopMobileMode(bool v) =>
      _persist(state.copyWith(desktopMobileMode: v));
  void setAgentAutomationMode(AgentAutomationMode v) =>
      _persist(state.copyWith(agentAutomationMode: v));
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.read(settingsRepoProvider)),
);

/// Provider derivado que sincroniza automáticamente el ThemeMode con settings
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.themeMode == 'Oscuro'
      ? ThemeMode.dark
      : settings.themeMode == 'Claro'
      ? ThemeMode.light
      : ThemeMode.system;
});
