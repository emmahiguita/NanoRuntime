/// AutomationModel (T4) — frontera explícita Modelo ↔ Automation.
///
/// El modelo es una CAPACIDAD CONFIGURABLE de Automation, NO su dueño. Automation
/// usa UN solo RuntimeEngineNotifier / LLMEngineClient (nunca un segundo motor)
/// y sigue determinista-primero: el modelo entra solo donde aporta valor
/// (selección de ambigüedad, planificación, comprensión, redacción, resumen).
library;

/// Cómo resuelve Automation qué modelo usar.
enum AutomationModelMode {
  /// Usa el modelo seleccionado actualmente en Chat (activeModelPath).
  sameAsChat,

  /// Usa un modelo específico configurado para Automation.
  specificModel,

  /// Sin IA generativa: PROHIBIDO invocar el LLM (0 llamadas). Degrada a
  /// resultado determinista / needsClarification / noPlan, nunca fallback.
  deterministicOnly,
}

/// Rol concreto que Automation puede asignar al modelo.
enum AutomationModelRole {
  planner,
  selector,
  intentUnderstanding,
  draftWriter,
  summarizer,
  reasoning,
  vision,
}

/// Perfil de automatización por modelo. Solo campos REALMENTE consumibles:
/// `temperature` se pasa a LLMEngineClient.generate(...) por request;
/// `contextSize` NO se expone por-request (es del runtime al cargar el GGUF),
/// así que no se modela (no afirmar que cambia por request).
class AutomationModelProfile {
  final String modelId;
  final String modelPath;
  final bool enabledForAutomation;
  final Set<AutomationModelRole> roles;
  final double temperature;

  const AutomationModelProfile({
    required this.modelId,
    required this.modelPath,
    this.enabledForAutomation = false,
    this.roles = const {},
    this.temperature = 0.7,
  });

  bool hasRole(AutomationModelRole role) => roles.contains(role);

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'modelPath': modelPath,
    'enabledForAutomation': enabledForAutomation,
    'roles': [for (final r in roles) r.name],
    'temperature': temperature,
  };

  factory AutomationModelProfile.fromJson(Map<String, dynamic> m) =>
      AutomationModelProfile(
        modelId: m['modelId'] as String? ?? '',
        modelPath: m['modelPath'] as String? ?? '',
        enabledForAutomation: m['enabledForAutomation'] as bool? ?? false,
        roles: {
          for (final r in (m['roles'] as List? ?? const []))
            AutomationModelRole.values.byName(r as String),
        },
        temperature: (m['temperature'] as num?)?.toDouble() ?? 0.7,
      );
}

/// Presets de asignación de modelos según la capacidad de hardware del dispositivo móvil.
abstract final class AutomationTierPresets {
  /// Gama económica (≤ 4GB RAM) — Foco en bajo consumo y permanencia en background.
  static const lightweight4Gb = AutomationHardwareTier(
    id: 'tier_4gb_lightweight',
    name: 'Ligero (Móviles ≤ 4GB RAM)',
    recommendedModel: 'LFM2.5-1.2B-Instruct-Q4_0-QAD',
    roles: {AutomationModelRole.draftWriter, AutomationModelRole.intentUnderstanding},
    estimatedRamGb: 1.1,
  );

  /// Gama media (6GB a 8GB RAM) — Comprensión semántica equilibrada y razonamiento bajo demanda.
  static const balanced6to8Gb = AutomationHardwareTier(
    id: 'tier_6_8gb_balanced',
    name: 'Equilibrado (Móviles 6GB a 8GB RAM)',
    recommendedModel: 'Qwen3.5-2B-Q4_K_M',
    reasoningModel: 'LFM2.5-1.2B-Thinking',
    roles: {
      AutomationModelRole.draftWriter,
      AutomationModelRole.intentUnderstanding,
      AutomationModelRole.selector,
      AutomationModelRole.reasoning,
    },
    estimatedRamGb: 1.8,
  );

  /// Gama alta (≥ 12GB RAM) — Capacidades avanzadas agentic y visión multimodal.
  static const advanced12Gb = AutomationHardwareTier(
    id: 'tier_12gb_advanced',
    name: 'Avanzado (Móviles ≥ 12GB RAM)',
    recommendedModel: 'LFM2.5-2.6B-Q4_0-QAD',
    visionModel: 'Gemma-3n-E2B-IT',
    roles: {
      AutomationModelRole.draftWriter,
      AutomationModelRole.intentUnderstanding,
      AutomationModelRole.selector,
      AutomationModelRole.planner,
      AutomationModelRole.reasoning,
      AutomationModelRole.vision,
    },
    estimatedRamGb: 2.2,
  );

  static const tiers = [lightweight4Gb, balanced6to8Gb, advanced12Gb];
}

class AutomationHardwareTier {
  final String id;
  final String name;
  final String recommendedModel;
  final String? reasoningModel;
  final String? visionModel;
  final Set<AutomationModelRole> roles;
  final double estimatedRamGb;

  const AutomationHardwareTier({
    required this.id,
    required this.name,
    required this.recommendedModel,
    this.reasoningModel,
    this.visionModel,
    required this.roles,
    required this.estimatedRamGb,
  });
}
