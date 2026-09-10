/// AUTO-03 — modos de autonomía del pipeline conversacional WhatsApp.
///
/// DISTINTO de `AgentAutomationMode` (automation_policy.dart): aquel gobierna
/// las herramientas del chat UI; este gobierna cuánto puede el pipeline de
/// notificaciones responder por sí solo. No se fusionan: son consumidores y
/// superficies distintas (chat interactivo vs turnos autónomos entrantes).
///
/// El modo NO es una política de agente: es un tope global que el
/// ConversationDecisionEngine aplica ANTES de su fórmula (ownership,
/// identidad, requiresAction, umbral 0.6 siguen intactos).
///
/// AUTONOMY FAIL-SAFE (PROD-02): el default dejó de ser `autonomous`. Todo
/// lo que NO sea una elección explícita persistida cae cerrado: `null`
/// (fresh install, settings legacy sin key, elección nunca hecha) →
/// `safeAuto` (solo lo seguro sale); nombre inválido → `disabled` (cero
/// envíos). FULL AUTONOMOUS solo existe si el dueño lo eligió en Ajustes
/// y quedó persistido con el nombre exacto del enum.
library;

/// Cuánto puede decidir el pipeline por sí solo.
enum ConversationAutonomyMode {
  /// Escucha (dedupe, memoria, trazas) pero jamás responde ni ejecuta.
  disabled,

  /// Genera el borrador, evalúa todas las guardas de calidad y retiene SIEMPRE
  /// para aprobación humana. El borrador reparado se persiste de forma durable
  /// en PendingReplyStore (SQLite) y se expone en la bandeja de la UI para
  /// que el usuario lo revise, edite, descarte o despache. Cero auto-envío.
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
      'Revisa y genera respuestas desde Mensajes; no hay envíos automáticos.',
    ConversationAutonomyMode.safeAuto =>
      'Solo responde lo seguro (saludos, datos verificados).',
    ConversationAutonomyMode.autonomous =>
      'Nano decide y responde según su motor de decisión.',
  };

  /// AUTONOMY FAIL-SAFE (PROD-02) — conversión en 3 vías:
  /// - nombre válido → ese modo (elección explícita persistida, intacta);
  /// - `null` (nunca elegido / fresh install / settings legacy sin key) →
  ///   `safeAuto`: lo seguro sale, jamás FULL AUTONOMOUS sin elección;
  /// - nombre inválido (valor corrupto) → `disabled`: fail closed, cero
  ///   envíos automáticos hasta que el dueño elija de nuevo en Ajustes.
  static ConversationAutonomyMode fromName(String? raw) {
    for (final m in ConversationAutonomyMode.values) {
      if (m.name == raw) return m;
    }
    return raw == null
        ? ConversationAutonomyMode.safeAuto
        : ConversationAutonomyMode.disabled;
  }
}
