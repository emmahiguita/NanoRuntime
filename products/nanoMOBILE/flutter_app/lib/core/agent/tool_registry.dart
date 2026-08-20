/// ToolRegistry + PolicyEngine — gobernanza del tool-calling (§12 del plan
/// de automatización: "Tool Registry" + "Controles obligatorios").
///
/// Toda herramienta que el agente puede ejecutar contra el dispositivo vive
/// en un registro con riesgo, timeout y requisito de confirmación. El motor
/// de política decide allow / needsConfirmation / denied ANTES de ejecutar:
///
///   - Herramienta desconocida → denied (el modelo ve el error y se corrige;
///     jamás se ejecuta algo fuera del registro).
///   - Presupuesto de pasos por turno agotado → denied (anti-bucle: un GGUF
///     pequeño que insiste en llamar tools no puede iterar para siempre).
///   - externalWrite sin confirmación → needsConfirmation (el humano decide).
///
/// Origen de la acción: los comandos `@` los escribe el usuario → autoría
/// humana = confirmación implícita. El tool-calling del LLM es agencia
/// autónoma → las escrituras externas SIEMPRE piden confirmación.
///
/// Puro: sin MethodChannel ni UI — testeable con fixtures.
library;

/// Riesgo de una herramienta. Orden creciente de impacto.
enum ToolRisk { none, read, device, externalWrite }

/// Definición registrada de una herramienta (análogo a ToolDefinition del
/// plan §12). [requiresConfirmation] solo aplica a agencia autónoma (LLM);
/// la autoría humana (`@comando`) la satisface implícitamente.
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    this.risk = ToolRisk.read,
    this.requiresConfirmation = false,
    this.timeout = const Duration(seconds: 10),
    this.description = '',
  });

  final String name;
  final ToolRisk risk;
  final bool requiresConfirmation;

  /// Tiempo máximo de ejecución. Al vencer, la acción se cancela con
  /// feedback legible (nunca cuelga el turno del chat).
  final Duration timeout;

  /// Descripción humana para el diálogo de confirmación y la ayuda.
  final String description;
}

/// Registro de herramientas con alias (verbos `@` en español → nombre
/// canónico). Única fuente de verdad de qué puede ejecutarse.
class ToolRegistry {
  ToolRegistry(
    Map<String, ToolDefinition> byName, {
    Map<String, String> aliases = const {},
  }) : _byName = byName,
       _aliases = aliases;

  final Map<String, ToolDefinition> _byName;
  final Map<String, String> _aliases;

  /// Registro por defecto del agente UI (canal com.nanoai/agent).
  static final ToolRegistry builtin = ToolRegistry(
    {for (final d in _builtinDefs) d.name: d},
    aliases: {
      'pantalla': 'screen',
      'resolver': 'resolve',
      'tocar': 'tap',
      'escribir': 'write',
      'notificaciones': 'notifications',
      'responder_notificacion': 'reply_notification',
      'atras': 'back',
      'atrás': 'back',
    },
  );

  static const List<ToolDefinition> _builtinDefs = [
    ToolDefinition(
      name: 'screen',
      risk: ToolRisk.read,
      description: 'Leer la pantalla actual del dispositivo',
    ),
    ToolDefinition(
      name: 'resolve',
      risk: ToolRisk.read,
      description: 'Resolver un selector contra el árbol de accesibilidad',
    ),
    ToolDefinition(
      name: 'tap',
      risk: ToolRisk.device,
      description: 'Tocar un elemento de la pantalla',
    ),
    ToolDefinition(
      name: 'back',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Presionar el botón atrás',
    ),
    ToolDefinition(
      name: 'write',
      risk: ToolRisk.externalWrite,
      requiresConfirmation: true,
      description: 'Escribir texto en un campo de una aplicación',
    ),
    ToolDefinition(
      name: 'notifications',
      risk: ToolRisk.read,
      description: 'Leer las notificaciones activas del dispositivo',
    ),
    ToolDefinition(
      name: 'reply_notification',
      risk: ToolRisk.externalWrite,
      requiresConfirmation: true,
      description: 'Responder una notificación en una aplicación externa',
    ),
  ];

  /// Resuelve [name] (con alias) al registro canónico; null si no existe.
  ToolDefinition? lookup(String name) => _byName[_aliases[name] ?? name];

  bool isKnown(String name) => lookup(name) != null;

  Iterable<ToolDefinition> get all => _byName.values;
}

/// Veredicto de la política para una llamada a herramienta.
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
  PolicyEngine({ToolRegistry? registry, this.maxStepsPerTurn = 6})
    : registry = registry ?? ToolRegistry.builtin;

  final ToolRegistry registry;

  /// Pasos máximos ejecutados por turno del usuario (anti-bucle).
  final int maxStepsPerTurn;

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
  }) {
    final tool = registry.lookup(toolName);
    if (tool == null) {
      return PolicyDecision._(
        PolicyVerdict.denied,
        reason: 'Herramienta desconocida "$toolName": no está en el registro',
      );
    }
    if (stepsUsed >= maxStepsPerTurn) {
      return PolicyDecision._(
        PolicyVerdict.denied,
        tool: tool,
        reason: 'límite de pasos por turno alcanzado ($maxStepsPerTurn)',
      );
    }
    final autonomousImpact =
        !humanInitiated &&
        (tool.requiresConfirmation || tool.risk.index >= ToolRisk.device.index);
    final needsConfirm = autonomousImpact && !confirmed;
    if (needsConfirm) {
      return PolicyDecision._(
        PolicyVerdict.needsConfirmation,
        tool: tool,
        reason:
            '${tool.name} escribe en otra app — requiere confirmación '
            'del usuario',
      );
    }
    return PolicyDecision._(PolicyVerdict.allow, tool: tool);
  }
}
