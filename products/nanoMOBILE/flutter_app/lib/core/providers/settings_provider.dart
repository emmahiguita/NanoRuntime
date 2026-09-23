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
    final legacyChatModelId = _prefs.getString('nanoai_active_model') ?? '';
    final legacyChatModelPath =
        _prefs.getString('nanoai_active_model_path') ?? '';
    final json = _prefs.getString(_k);
    if (json == null) {
      return SettingsState(
        chatModelId: legacyChatModelId,
        chatModelPath: legacyChatModelPath,
      );
    }
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      // DARK-ONLY (decisión del dueño, 2026-09-05, confirmada en validación):
      // cualquier valor que no sea 'Oscuro' (ausente, 'Sistema' de defaults
      // viejos o 'Claro' guardado) se carga como 'Oscuro'. El dispositivo
      // quedó en claro por valores heredados y el usuario percibía las
      // superficies claras como "pantalla gris" al navegar. El selector de
      // tema sigue disponible en Ajustes para cambios futuros conscientes.
      return SettingsState(
        themeMode: 'Oscuro',
        temperature: (m['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (m['topP'] as num?)?.toDouble() ?? 0.9,
        maxTokens: (m['maxTokens'] as num?)?.toInt() ?? 512,
        vncPassword: m['vncPassword'] as String? ?? '',
        // El escritorio Linux de Nano es mobile-first. Una preferencia PC
        // antigua reintroducía barras grandes y podía reducir el framebuffer
        // a una franja durante la rotación.
        desktopMobileMode: true,
        agentAutomationMode: AgentAutomationMode.fromName(
          m['agentAutomationMode'] as String?,
        ),
        automationModelMode: _modeFromName(m['automationModelMode'] as String?),
        automationModelId: m['automationModelId'] as String? ?? '',
        automationModelPath: m['automationModelPath'] as String? ?? '',
        // MODELO-HEADLESS-01 — espejo durable de la selección del Chat. El
        // engine headless hidrata Settings antes de drenar el inbox y no
        // depende de que ChatNotifier haya terminado su restauración async.
        chatModelId: m['chatModelId'] as String? ?? legacyChatModelId,
        chatModelPath: m['chatModelPath'] as String? ?? legacyChatModelPath,
        voiceEnabled: m['voiceEnabled'] as bool? ?? true,
        waStyleEnabled: m['waStyleEnabled'] as bool? ?? false,
        waStyleText: m['waStyleText'] as String? ?? '',
        waReplyDelaySeconds: (m['waReplyDelaySeconds'] as num?)?.toInt() ?? 0,
        waTargetContactsMode: m['waTargetContactsMode'] as String? ?? 'all',
        // AUTONOMY FAIL-SAFE (PROD-02): key ausente/legacy → null (jamás
        // 'autonomous' por defecto). La conversión segura la hace
        // ConversationAutonomyModeName.fromName (null → safeAuto).
        waAutonomyMode: m['waAutonomyMode'] as String?,
        glassEnabled: m['glassEnabled'] as bool? ?? true,
        glassOpacity: (m['glassOpacity'] as num?)?.toDouble() ?? 0.70,
        glassClarity: (m['glassClarity'] as num?)?.toDouble() ?? 0.85,
        glassBlur: (m['glassBlur'] as num?)?.toDouble() ?? 18.0,
      );
    } catch (_) {
      // Un campo nuevo corrupto no debe borrar la selección legacy del
      // modelo: conservarla permite que ChatNotifier intente recuperarla y
      // que el usuario no pierda el chat tras una migración parcial.
      return SettingsState(
        chatModelId: legacyChatModelId,
        chatModelPath: legacyChatModelPath,
      );
    }
  }

  Future<void> save(SettingsState s) async {
    if (!_ready) await init();
    final ok = await _prefs.setString(
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
        'chatModelId': s.chatModelId,
        'chatModelPath': s.chatModelPath,
        'voiceEnabled': s.voiceEnabled,
        'waStyleEnabled': s.waStyleEnabled,
        'waStyleText': s.waStyleText,
        'waReplyDelaySeconds': s.waReplyDelaySeconds,
        'waTargetContactsMode': s.waTargetContactsMode,
        'waAutonomyMode': s.waAutonomyMode,
        'glassEnabled': s.glassEnabled,
        'glassOpacity': s.glassOpacity,
        'glassClarity': s.glassClarity,
        'glassBlur': s.glassBlur,
      }),
    );
    if (!ok) {
      throw StateError('Fallo al persistir SettingsState en SharedPreferences');
    }
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

  /// MODELO-HEADLESS-01 — selección del Chat replicada en el documento de
  /// ajustes que la barrera de automatización hidrata antes del primer evento.
  final String chatModelId;
  final String chatModelPath;

  /// V1 — voz (TTS) activada. Cuando false, speakLastResponse() es no-op.
  final bool voiceEnabled;

  /// WA-PERSONA-01 — agente WhatsApp "conteste como yo". Cuando true, los
  /// prompts de respuesta (reglas y sugerencias manuales) reciben el bloque
  /// MI ESTILO con [waStyleText]. Off = comportamiento idéntico al anterior.
  final bool waStyleEnabled;
  final String waStyleText;

  /// WA-DELAY-01 — pausa "humana" antes de despachar un reply automático de
  /// WhatsApp (0 = inmediato). El draft se redacta al recibir el mensaje; la
  /// pausa ocurre antes de la verificación supersede y del envío: si llega un
  /// mensaje nuevo durante la espera, el reply se descarta (nunca se envía).
  final int waReplyDelaySeconds;

  /// AUTO-03 — modo de autonomía del pipeline de WhatsApp (nombre del enum
  /// ConversationAutonomyMode: disabled/suggestions/safeAuto/autonomous).
  /// AUTONOMY FAIL-SAFE (PROD-02): `null` = el dueño NUNCA eligió un modo
  /// (fresh install, settings legacy sin key, JSON corrupto). La conversión
  /// la hace el coordinator con fromName: null → safeAuto, inválido →
  /// disabled. FULL AUTONOMOUS solo con 'autonomous' persistido explícito.
  final String? waAutonomyMode;

  /// CONTACT-POLICY-01 — modo de activación del agente en contactos:
  /// 'all': responde a todos los contactos de WhatsApp (salvo pausados a mano).
  /// 'selected': responde ÚNICAMENTE a los contactos explícitamente activados.
  final String waTargetContactsMode;

  /// Vidrio Líquido hiperrealista estilo iOS (GlassSurface).
  final bool glassEnabled;
  final double glassOpacity;
  final double glassClarity;
  final double glassBlur;

  const SettingsState({
    this.themeMode = 'Oscuro',
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 512,
    this.vncPassword = '',
    this.desktopMobileMode = true,
    this.agentAutomationMode = AgentAutomationMode.assisted,
    this.automationModelMode = AutomationModelMode.sameAsChat,
    this.automationModelId = '',
    this.automationModelPath = '',
    this.chatModelId = '',
    this.chatModelPath = '',
    this.voiceEnabled = true,
    this.waStyleEnabled = false,
    this.waStyleText = '',
    this.waReplyDelaySeconds = 0,
    this.waTargetContactsMode = 'all',
    this.waAutonomyMode,
    this.glassEnabled = true,
    this.glassOpacity = 0.70,
    this.glassClarity = 0.85,
    this.glassBlur = 18.0,
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
    String? chatModelId,
    String? chatModelPath,
    bool? voiceEnabled,
    bool? waStyleEnabled,
    String? waStyleText,
    int? waReplyDelaySeconds,
    String? waTargetContactsMode,
    String? waAutonomyMode,
    bool? glassEnabled,
    double? glassOpacity,
    double? glassClarity,
    double? glassBlur,
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
    chatModelId: chatModelId ?? this.chatModelId,
    chatModelPath: chatModelPath ?? this.chatModelPath,
    voiceEnabled: voiceEnabled ?? this.voiceEnabled,
    waStyleEnabled: waStyleEnabled ?? this.waStyleEnabled,
    waStyleText: waStyleText ?? this.waStyleText,
    waReplyDelaySeconds: waReplyDelaySeconds ?? this.waReplyDelaySeconds,
    waTargetContactsMode: waTargetContactsMode ?? this.waTargetContactsMode,
    waAutonomyMode: waAutonomyMode ?? this.waAutonomyMode,
    glassEnabled: glassEnabled ?? this.glassEnabled,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glassClarity: glassClarity ?? this.glassClarity,
    glassBlur: glassBlur ?? this.glassBlur,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;
  final Future<void> Function()? _stopVoiceOutput;

  SettingsState _durableState = const SettingsState();
  int _mutationRevision = 0;
  int _durableRevision = 0;

  SettingsNotifier(this._repo, {Future<void> Function()? stopVoiceOutput})
    : _stopVoiceOutput = stopVoiceOutput,
      super(const SettingsState());

  Future<void> init() async {
    await _repo.init();
    final loaded = await _repo.load();
    _durableState = loaded;
    _mutationRevision = 0;
    _durableRevision = 0;
    state = loaded;
    // themeModeProvider ahora es derivado y se sincroniza automáticamente
  }

  Future<void> _lastWrite = Future<void>.value();

  Future<void> _persist(SettingsState s) {
    final rev = ++_mutationRevision;
    state = s;
    final write = _lastWrite.then((_) async {
      // Conflación de escrituras: si una mutación más reciente ya fue encolada
      // (ej. arrastre continuo de sliders), omitimos el tick obsoleto en disco.
      if (rev != _mutationRevision) return;
      try {
        await _repo.save(s);
        if (rev >= _durableRevision) {
          _durableRevision = rev;
          _durableState = s;
        }
      } catch (e) {
        // FAIL-SAFE (PROD-01): si el disco rechaza la escritura o falla el IO,
        // revertimos RAM a la última verdad duradera para que la UI jamás
        // afirme un modo (ej. 'Disabled') que el disco no consolidó.
        // Solo revertimos si no hay una mutación más reciente en vuelo.
        debugPrint(
          '[settings] fallo al persistir en disco (rev=$rev): $e — rollback',
        );
        if (rev == _mutationRevision) {
          state = _durableState;
        }
        rethrow;
      }
    });
    _lastWrite = write.catchError((Object _) {});
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

  /// Se invoca al elegir un modelo en Chat, antes de intentar arrancar el
  /// runtime. Así una carga lenta o fallida no pierde la selección necesaria
  /// para el siguiente arranque headless.
  void setChatModel(String id, String path) =>
      _persist(state.copyWith(chatModelId: id, chatModelPath: path));

  /// WA-PERSONA-01 — toggle del estilo del agente WhatsApp. Persist inmediata
  /// (mismo patrón que el resto de setters); las closures de los writers leen
  /// el estado en vivo al redactar, sin watch.
  void setWaStyleEnabled(bool v) => _persist(state.copyWith(waStyleEnabled: v));

  void setWaStyleText(String v) => _persist(state.copyWith(waStyleText: v));

  /// WA-DELAY-01 — pausa de reply en segundos (0..60, clampa la UI).
  void setWaReplyDelaySeconds(int v) =>
      _persist(state.copyWith(waReplyDelaySeconds: v.clamp(0, 60)));

  /// AUTO-03 — modo de autonomía del pipeline de WhatsApp. String crudo
  /// (patrón themeMode): el coordinator lo convierte con
  /// ConversationAutonomyMode.fromName. AUTONOMY FAIL-SAFE (PROD-02):
  /// solo la UI escribe aquí, SIEMPRE con un nombre válido del enum
  /// (elección explícita del dueño); null = jamás elegido.
  void setWaAutonomyMode(String v) =>
      _persist(state.copyWith(waAutonomyMode: v));

  /// CONTACT-POLICY-01 — fija modo de contacto ('all' o 'selected').
  void setWaTargetContactsMode(String v) =>
      _persist(state.copyWith(waTargetContactsMode: v));

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

  /// GLASS-01 — Configuración óptica hiperrealista iOS GlassSurface.
  void setGlassEnabled(bool v) => _persist(state.copyWith(glassEnabled: v));
  void setGlassOpacity(double v) =>
      _persist(state.copyWith(glassOpacity: v.clamp(0.05, 1.0)));
  void setGlassClarity(double v) =>
      _persist(state.copyWith(glassClarity: v.clamp(0.0, 1.0)));
  void setGlassBlur(double v) =>
      _persist(state.copyWith(glassBlur: v.clamp(0.0, 40.0)));
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
