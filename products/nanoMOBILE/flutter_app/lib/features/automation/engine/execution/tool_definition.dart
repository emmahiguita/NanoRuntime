part of 'tool_registry.dart';

/// Describe entradas, efecto y consentimiento por identidad canónica.
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    ToolRisk? risk,
    bool? requiresConfirmation,
    bool? irreversible,
    this.timeout = const Duration(seconds: 10),
    this.description = '',
    this.promptSyntax,
  }) : _riskOverride = risk,
       _confirmationOverride = requiresConfirmation,
       _irreversibleOverride = irreversible,
       _usesCanonicalPolicy =
           risk == null && requiresConfirmation == null && irreversible == null;

  bool get hasExplicitPolicy => !_usesCanonicalPolicy;

  final String name;
  final ToolRisk? _riskOverride;
  final bool? _confirmationOverride;
  final bool? _irreversibleOverride;
  final bool _usesCanonicalPolicy;

  SemanticActionDefinition get semanticPolicy =>
      automationSemanticPolicy(name) ??
      const SemanticActionDefinition(
        risk: SemanticActionRisk.irreversibleCommit,
        irreversible: true,
        requiresConfirmation: true,
      );

  ToolRisk get risk =>
      _riskOverride ??
      (_usesCanonicalPolicy
          ? switch (semanticPolicy.risk) {
              SemanticActionRisk.observation => ToolRisk.read,
              SemanticActionRisk.navigation => ToolRisk.device,
              SemanticActionRisk.reversibleWrite ||
              SemanticActionRisk.irreversibleCommit => ToolRisk.externalWrite,
            }
          : ToolRisk.read);

  bool get requiresConfirmation =>
      _confirmationOverride ??
      (_usesCanonicalPolicy ? semanticPolicy.requiresConfirmation : false);

  /// La acción puede producir un efecto externo no repetible o cuyo resultado
  /// quede incierto. Debe reclamar el journal durable antes de ejecutar.
  bool get irreversible =>
      _irreversibleOverride ??
      (_usesCanonicalPolicy ? semanticPolicy.irreversible : false);

  SemanticReplayPolicy get replayPolicy => semanticPolicy.replayPolicy;
  RequiredEvidence get requiredEvidence => semanticPolicy.requiredEvidence;
  List<String> get requiredInputs => semanticPolicy.requiredInputs;
  bool get requiresContextLock => semanticPolicy.requiresContextLock;

  /// Tiempo máximo de ejecución. Al vencer, la acción se cancela con
  /// feedback legible (nunca cuelga el turno del chat).
  final Duration timeout;

  /// Descripción humana para el diálogo de confirmación y la ayuda.
  final String description;

  /// JSON canónico que el modelo local puede emitir. null mantiene la
  /// herramienta disponible para flujos deterministas, pero evita anunciarla
  /// al LLM cuando todavía no existe un catálogo que impida argumentos
  /// inventados (por ejemplo packageName de launch_app).
  final String? promptSyntax;
}
