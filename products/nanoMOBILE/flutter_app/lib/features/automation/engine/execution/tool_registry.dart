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
    this.promptSyntax,
  });

  final String name;
  final ToolRisk risk;
  final bool requiresConfirmation;

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
      'inicio': 'home',
      'recientes': 'recents',
      'sombra': 'open_notifications',
      'ajustes_rapidos': 'open_quick_settings',
    },
  );

  static const List<ToolDefinition> _builtinDefs = [
    ToolDefinition(
      name: 'screen',
      risk: ToolRisk.read,
      description: 'Leer la pantalla actual del dispositivo',
      promptSyntax: '{"tool":"screen"}',
    ),
    ToolDefinition(
      name: 'resolve',
      risk: ToolRisk.read,
      description: 'Resolver un selector contra el árbol de accesibilidad',
      promptSyntax: '{"tool":"resolve","selector":"<selector>"}',
    ),
    ToolDefinition(
      name: 'tap',
      risk: ToolRisk.device,
      description: 'Tocar un elemento de la pantalla',
      promptSyntax: '{"tool":"tap","selector":"<selector>"}',
    ),
    ToolDefinition(
      name: 'back',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Presionar el botón atrás',
      promptSyntax: '{"tool":"back"}',
    ),
    ToolDefinition(
      name: 'launch_app',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 10),
      description: 'Abrir una aplicación instalada por su paquete Android',
    ),
    ToolDefinition(
      name: 'write',
      risk: ToolRisk.externalWrite,
      requiresConfirmation: true,
      description: 'Escribir texto en un campo de una aplicación',
      promptSyntax: '{"tool":"write","selector":"<selector>","text":"<texto>"}',
    ),
    ToolDefinition(
      name: 'notifications',
      risk: ToolRisk.read,
      description: 'Leer las notificaciones activas del dispositivo',
      promptSyntax: '{"tool":"notifications"}',
    ),
    ToolDefinition(
      name: 'reply_notification',
      risk: ToolRisk.externalWrite,
      requiresConfirmation: true,
      description: 'Responder una notificación en una aplicación externa',
      promptSyntax:
          '{"tool":"reply_notification","key":"<key>","text":"<texto>"}',
    ),
    // ── Subsistema Linux (C9) — acceso estructurado, nunca bash libre sin
    // política. Los writes piden confirmación; run es device (puede ser
    // destructivo: la política evalúa por comando en el dispatcher).
    ToolDefinition(
      name: 'linux.list',
      risk: ToolRisk.read,
      timeout: Duration(seconds: 15),
      description: 'Listar archivos en el subsistema Linux',
    ),
    ToolDefinition(
      name: 'linux.readFile',
      risk: ToolRisk.read,
      timeout: Duration(seconds: 15),
      description: 'Leer un archivo del subsistema Linux',
    ),
    ToolDefinition(
      name: 'linux.writeFile',
      risk: ToolRisk.externalWrite,
      requiresConfirmation: true,
      timeout: Duration(seconds: 20),
      description: 'Escribir un archivo en el subsistema Linux',
    ),
    ToolDefinition(
      name: 'linux.run',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 30),
      description: 'Ejecutar un comando en el subsistema Linux',
    ),
    // ── Device Actions V1 (A1) ─────────────────────────────────────────────
    // Capacidades nativas YA existentes en AgentAccessibilityService, elevadas
    // a tools tipadas. `promptSyntax: null` = disponibles para flujos
    // deterministas y comandos `@`, pero NO anunciadas al LLM: el grounding
    // de swipe/scroll/long_press lo gobernará Candidate-First (A5/A6), y las
    // global actions no deben ser elegidas por un modelo sin evidencia del
    // estado del dispositivo.
    ToolDefinition(
      name: 'home',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Ir a la pantalla de inicio',
    ),
    ToolDefinition(
      name: 'recents',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Abrir la vista de aplicaciones recientes',
    ),
    ToolDefinition(
      name: 'open_notifications',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Abrir la sombra de notificaciones',
    ),
    ToolDefinition(
      name: 'open_quick_settings',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Abrir los ajustes rápidos',
    ),
    ToolDefinition(
      name: 'swipe',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Deslizar entre dos puntos de la pantalla',
    ),
    ToolDefinition(
      name: 'scroll',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Desplazar la pantalla en una dirección',
    ),
    ToolDefinition(
      name: 'long_press',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Mantener pulsado un punto de la pantalla',
    ),
    // ── System destination (A3) ─────────────────────────────────────────────
    // Navegación de sistema allowlisted. promptSyntax null = no visible al LLM:
    // el destino es un ID semántico validado contra el enum, nunca un string
    // crudo de Intent inventable por el modelo.
    ToolDefinition(
      name: 'open_system',
      risk: ToolRisk.device,
      timeout: Duration(seconds: 5),
      description: 'Abrir un destino de sistema allowlisted',
    ),
    // A14.4: Shizuku TIPADO. Solo capacidad read (queryPackage). El resto
    // (install/forceStop/grant) queda sin registrar hasta validar en device.
    // promptSyntax null: la invoca el humano/high-level, no el LLM (aún), para
    // no inflar el prompt móvil.
    ToolDefinition(
      name: 'shizuku_query_package',
      risk: ToolRisk.read,
      timeout: Duration(seconds: 15),
      description:
          'Consultar metadatos de un paquete con privilegios Shizuku (solo lectura)',
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
