/// Política de automatización del agente.
///
/// Define cuándo una acción del LLM debe pedir confirmación al usuario antes
/// de ejecutarse sobre el dispositivo. Vive en el dominio de automation (no en
/// settings ni en chat) porque es una regla de negocio, no una preferencia de
/// UI ni un detalle del flujo de conversación.
library;

/// Nivel de autonomía del agente de chat.
///
/// Se persiste en settings como `agentAutomationMode.name`, pero el tipo
/// pertenece al dominio de automatización: es la fuente de verdad del gating
/// de acciones sobre el dispositivo.
enum AgentAutomationMode {
  manual,
  assisted,
  autonomous;

  static AgentAutomationMode fromName(String? name) {
    for (final mode in AgentAutomationMode.values) {
      if (mode.name == name) return mode;
    }
    return AgentAutomationMode.assisted;
  }

  String get label => switch (this) {
    AgentAutomationMode.manual => 'Manual',
    AgentAutomationMode.assisted => 'Asistido',
    AgentAutomationMode.autonomous => 'Autónomo',
  };

  String get description => switch (this) {
    AgentAutomationMode.manual =>
      'Nano puede observar. Cualquier acción que modifique o controle el '
          'dispositivo requiere tu confirmación.',
    AgentAutomationMode.assisted =>
      'Nano ejecuta acciones seguras y te consulta antes de acciones '
          'sensibles.',
    AgentAutomationMode.autonomous =>
      'Nano completa tareas permitidas por sí mismo. Las acciones sensibles '
          'siguen protegidas por políticas.',
  };
}

/// Decide, dado un nivel de autonomía, si una herramienta concreta requiere
/// confirmación del usuario antes de actuar sobre el dispositivo.
///
/// Extraído de `ChatNotifier` para que la política sea testeable y reutilizable
/// sin acoplar el chat al dominio de automation.
class AutomationPolicy {
  final AgentAutomationMode mode;
  const AutomationPolicy(this.mode);

  /// Herramientas de solo lectura exentas de confirmación en modo manual.
  static const _readOnlyTools = {
    'screen',
    'resolve',
    'notifications',
    'linux.list',
    'linux.readFile',
    'shizuku_query_package',
  };

  /// Operaciones con efecto externo o de privilegio que requieren una decisión
  /// explícita en los modos asistido y autónomo. Navegación (`tap`, `back`,
  /// `launch_app`, gestos) no entra aquí: es una precondición, no una acción
  /// final por sí misma.
  static const _sensitiveTools = {
    'write',
    'reply_notification',
    'linux.writeFile',
    'force_stop_package',
    'install_package',
    'grant_specific_permission',
  };

  bool requiresConfirmation(String tool) => switch (mode) {
    AgentAutomationMode.manual => !_readOnlyTools.contains(tool),
    AgentAutomationMode.assisted ||
    AgentAutomationMode.autonomous => _sensitiveTools.contains(tool),
  };

  String confirmationDescription(String tool) =>
      '[policy] "$tool" requiere confirmación en modo ${mode.label} '
      'antes de actuar sobre el dispositivo.';
}
