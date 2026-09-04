import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';

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
        maxTokens: (m['maxTokens'] as num?)?.toInt() ?? 512,
        vncPassword: m['vncPassword'] as String? ?? '',
        desktopMobileMode: m['desktopMobileMode'] as bool? ?? false,
        agentAutomationMode: AgentAutomationMode.fromName(
          m['agentAutomationMode'] as String?,
        ),
        automationModelMode: _modeFromName(m['automationModelMode'] as String?),
        automationModelId: m['automationModelId'] as String? ?? '',
        automationModelPath: m['automationModelPath'] as String? ?? '',
        voiceEnabled: m['voiceEnabled'] as bool? ?? true,
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
        'automationModelMode': s.automationModelMode.name,
        'automationModelId': s.automationModelId,
        'automationModelPath': s.automationModelPath,
        'voiceEnabled': s.voiceEnabled,
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

  /// T4 — cómo resuelve Automation su modelo (sameAsChat/specificModel/deterministicOnly).
  final AutomationModelMode automationModelMode;

  /// T4 — modelo específico de Automation (cuando mode == specificModel).
  final String automationModelId;
  final String automationModelPath;

  /// V1 — voz (TTS) activada. Cuando false, speakLastResponse() es no-op.
  final bool voiceEnabled;

  const SettingsState({
    this.themeMode = 'Sistema',
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 512,
    this.vncPassword = '',
    this.desktopMobileMode = false,
    this.agentAutomationMode = AgentAutomationMode.assisted,
    this.automationModelMode = AutomationModelMode.sameAsChat,
    this.automationModelId = '',
    this.automationModelPath = '',
    this.voiceEnabled = true,
  });

  SettingsState copyWith({
    String? themeMode,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? vncPassword,
    bool? desktopMobileMode,
    AgentAutomationMode? agentAutomationMode,
    AutomationModelMode? automationModelMode,
    String? automationModelId,
    String? automationModelPath,
    bool? voiceEnabled,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    temperature: temperature ?? this.temperature,
    topP: topP ?? this.topP,
    maxTokens: maxTokens ?? this.maxTokens,
    vncPassword: vncPassword ?? this.vncPassword,
    desktopMobileMode: desktopMobileMode ?? this.desktopMobileMode,
    agentAutomationMode: agentAutomationMode ?? this.agentAutomationMode,
    automationModelMode: automationModelMode ?? this.automationModelMode,
    automationModelId: automationModelId ?? this.automationModelId,
    automationModelPath: automationModelPath ?? this.automationModelPath,
    voiceEnabled: voiceEnabled ?? this.voiceEnabled,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;
  final Future<void> Function()? _stopVoiceOutput;

  SettingsNotifier(this._repo, {Future<void> Function()? stopVoiceOutput})
    : _stopVoiceOutput = stopVoiceOutput,
      super(const SettingsState());

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
  void setAutomationModelMode(AutomationModelMode v) =>
      _persist(state.copyWith(automationModelMode: v));
  void setAutomationModel(String id, String path) => _persist(
    state.copyWith(automationModelId: id, automationModelPath: path),
  );

  /// Gate global de salida TTS. El estado cambia antes de cualquier await para
  /// que ninguna nueva respuesta pueda empezar a hablar; al apagar también
  /// detiene de inmediato la locución nativa que ya estuviera en curso.
  Future<void> setVoiceEnabled(bool v) async {
    if (state.voiceEnabled == v) return;
    final write = _persist(state.copyWith(voiceEnabled: v));
    if (!v) {
      try {
        await _stopVoiceOutput?.call();
      } catch (_) {
        // El gate queda apagado aunque Android no confirme el stop.
      }
    }
    await write;
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(
    ref.read(settingsRepoProvider),
    stopVoiceOutput: () async {
      await NanoRuntimeApi.instance.stopSpeech();
    },
  ),
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

/// Deserializa AutomationModelMode por nombre, degradando a sameAsChat si el
/// valor persistido es desconocido (no inventa un modo).
AutomationModelMode _modeFromName(String? name) {
  for (final m in AutomationModelMode.values) {
    if (m.name == name) return m;
  }
  return AutomationModelMode.sameAsChat;
}
