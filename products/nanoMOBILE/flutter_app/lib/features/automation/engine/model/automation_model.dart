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
