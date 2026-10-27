part of 'tool_registry.dart';

/// Decide antes de ejecutar: una clasificación o un modelo no conceden permiso.
enum PolicyVerdict { allow, needsConfirmation, denied }

/// Decisión del [PolicyEngine] con motivo legible (va al trace del modelo
/// y al chat — honestidad: el agente explica POR QUÉ no actuó).
class PolicyDecision {
  const PolicyDecision._(this.verdict, {this.tool, this.reason = ''});

  final PolicyVerdict verdict;
  final ToolDefinition? tool;
  final String reason;

  bool get allowed => verdict == PolicyVerdict.allow;
  bool get denied => verdict == PolicyVerdict.denied;
  bool get needsConfirmation => verdict == PolicyVerdict.needsConfirmation;

  @override
  String toString() => 'PolicyDecision(${verdict.name}, $reason)';
}

/// Motor de política: decide sin ejecutar. Puro y determinista.
class PolicyEngine {
  PolicyEngine({
    ToolRegistry? registry,
    this.maxStepsPerTurn = 8,
    bool Function(String toolName)? confirmationPolicy,
  }) : registry = registry ?? ToolRegistry.builtin,
       _confirmationPolicy = confirmationPolicy;

  final ToolRegistry registry;
  final bool Function(String toolName)? _confirmationPolicy;

  /// Pasos máximos ejecutados por turno del usuario (anti-bucle).
  final int maxStepsPerTurn;

  /// Fuente semántica única para confirmación. Producción inyecta la política
  /// del modo actual; instancias aisladas conservan el metadata del registro.
  bool requiresConfirmation(String toolName) {
    final canonicalName = registry.lookup(toolName)?.name ?? toolName;
    final definition = automationSemanticPolicy(canonicalName);
    if (definition == null) {
      return registry.lookup(canonicalName)?.requiresConfirmation ?? true;
    }
    // Un modo de autonomía no puede rebajar una acción sensible canónica.
    return definition.requiresConfirmation ||
        (_confirmationPolicy?.call(canonicalName) ?? false);
  }

  /// Decide sobre [toolName] con el contexto de uso actual.
  ///
  /// [stepsUsed]: pasos ya ejecutados en este turno (sin contar este).
  /// [humanInitiated]: true si la acción la escribió el humano (`@comando`)
  /// — cuenta como confirmación implícita de escrituras externas.
  /// [confirmed]: true si el usuario ya aprobó explícitamente esta llamada
  /// en el diálogo de confirmación.
  PolicyDecision decide(
    String toolName, {
    required int stepsUsed,
    bool humanInitiated = false,
    bool confirmed = false,
    String? semanticAction,
  }) {
    final tool = registry.lookup(toolName);
    if (tool == null) {
      return PolicyDecision._(
        PolicyVerdict.denied,
        reason: 'Herramienta desconocida "$toolName": no está en el registro',
      );
    }
    if (automationSemanticPolicy(tool.name) == null &&
        !tool.hasExplicitPolicy) {
      return PolicyDecision._(
        PolicyVerdict.denied,
        tool: tool,
        reason: 'Herramienta sin contrato de seguridad: ${tool.name}',
      );
    }
    if (semanticAction != null &&
        automationSemanticPolicy(semanticAction) == null) {
      return PolicyDecision._(
        PolicyVerdict.denied,
        tool: tool,
        reason: 'Semántica desconocida "$semanticAction": sin política',
      );
    }
    if (stepsUsed >= maxStepsPerTurn) {
      return PolicyDecision._(
        PolicyVerdict.denied,
        tool: tool,
        reason: 'límite de pasos por turno alcanzado ($maxStepsPerTurn)',
      );
    }
    // `risk` describe impacto técnico, no el consentimiento. Navegar (tap,
    // back, launch) es necesario para completar una tarea y no debe duplicar
    // el diálogo que ya gobierna AutomationPolicy. Solo las tools marcadas de
    // forma explícita como sensibles requieren una aprobación autónoma.
    // Una ejecución semántica ya fue validada por IntentFirewall y usa la
    // política canónica de esa acción. Volver a sumar la política de la tool
    // física convertiría una sola acción reversible en varias confirmaciones
    // (p. ej. escribir el término de búsqueda y luego el borrador). Las llamadas
    // crudas, sin semántica, conservan la política conservadora de la tool.
    final policySubject = semanticAction ?? tool.name;
    final autonomousImpact =
        !humanInitiated && requiresConfirmation(policySubject);
    final needsConfirm = autonomousImpact && !confirmed;
    if (needsConfirm) {
      return PolicyDecision._(
        PolicyVerdict.needsConfirmation,
        tool: tool,
        reason:
            '${semanticAction ?? tool.name} requiere confirmación '
            'del usuario',
      );
    }
    return PolicyDecision._(PolicyVerdict.allow, tool: tool);
  }
}
