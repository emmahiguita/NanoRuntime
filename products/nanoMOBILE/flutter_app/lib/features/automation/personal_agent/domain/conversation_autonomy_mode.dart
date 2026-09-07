/// AUTO-03 — modos de autonomía del pipeline conversacional WhatsApp.
///
/// DISTINTO de `AgentAutomationMode` (automation_policy.dart): aquel gobierna
/// las herramientas del chat UI; este gobierna cuánto puede el pipeline de
/// notificaciones responder por sí solo. No se fusionan: son consumidores y
/// superficies distintas (chat interactivo vs turnos autónomos entrantes).
///
/// El modo NO es una política de agente: es un tope global que el
/// ConversationDecisionEngine aplica ANTES de su fórmula (ownership,
/// identidad, requiresAction, umbral 0.6 siguen intactos). Default
/// `autonomous` = paridad exacta con el comportamiento actual (cero riesgo
/// de regresión al persistir por primera vez).
library;

/// Cuánto puede decidir el pipeline por sí solo.
enum ConversationAutonomyMode {
  /// Escucha (dedupe, memoria, trazas) pero jamás responde ni ejecuta.
  disabled,

  /// Genera el borrador, la decisión retiene SIEMPRE: solo aprobación
  /// humana lo suelta. (Hoy el draft retenido se descarta y se traza; la
  /// cola de borradores con aprobación en UI es el siguiente sprint — sin
  /// superficie de lectura no se persiste, regla: nada de write sin read.)
  suggestions,

  /// Responde solo lo seguro: riesgo LOW y sin hechos faltantes. Un saludo
  /// o un precio verificado salen; lo que pida datos ausentes se retiene.
  safeAuto,

  /// Modo completo: el motor de decisión aplica su fórmula normal.
  autonomous,
}

extension ConversationAutonomyModeName on ConversationAutonomyMode {
  String get name => switch (this) {
    ConversationAutonomyMode.disabled => 'disabled',
    ConversationAutonomyMode.suggestions => 'suggestions',
    ConversationAutonomyMode.safeAuto => 'safeAuto',
    ConversationAutonomyMode.autonomous => 'autonomous',
  };

  String get label => switch (this) {
    ConversationAutonomyMode.disabled => 'Desactivado',
    ConversationAutonomyMode.suggestions => 'Sugerencias',
    ConversationAutonomyMode.safeAuto => 'Auto seguro',
    ConversationAutonomyMode.autonomous => 'Autónomo',
  };

  String get description => switch (this) {
    ConversationAutonomyMode.disabled =>
      'Nano escucha pero no responde en WhatsApp.',
    ConversationAutonomyMode.suggestions =>
      'Nano prepara la respuesta y espera tu aprobación.',
    ConversationAutonomyMode.safeAuto =>
      'Solo responde lo seguro (saludos, datos verificados).',
    ConversationAutonomyMode.autonomous =>
      'Nano decide y responde según su motor de decisión.',
  };

  static ConversationAutonomyMode fromName(String? raw) {
    return ConversationAutonomyMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ConversationAutonomyMode.autonomous,
    );
  }
}
