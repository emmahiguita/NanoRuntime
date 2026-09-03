/// ScheduledRule (T3.1) — regla de automatización persistente, WhatsApp-first.
///
/// Una regla NO ejecuta shell/UI directamente: es la declaración autorizada de
/// "cuando <trigger>, haz <action>". La ejecución la hace el AutomationCoordinator
/// (mismo motor, nunca un agente paralelo). La regla conserva que fue creada
/// EXPLÍCITAMENTE por el usuario ([createdByUser]) — esa es la autoridad para
/// ejecutar luego sin pedir confirmación en cada evento.
library;

import 'trigger.dart';

/// Qué hace la regla cuando el trigger dispara. La acción de envío (`reply`)
/// es la única que toca el dispositivo; `draft` solo prepara texto y `notify`
/// solo avisa. El destinatario y la autorización para enviar son deterministas
/// (vienen de la notificación/ScreenGraph), nunca los decide el LLM.
enum RuleAction {
  /// Solo avisar al usuario ("cuando Juan me escriba, avísame").
  notify,

  /// Preparar una respuesta sin enviarla ("prepara una respuesta").
  draft,

  /// Enviar la respuesta (RemoteInput o fallback UI) ("responde '...'").
  reply,
}

class ScheduledRule {
  final String id;

  /// Condición de disparo (típicamente NotificationTrigger para WhatsApp).
  final Trigger trigger;

  /// Acción autorizada al disparar.
  final RuleAction action;

  /// Texto fijo de respuesta (para `reply`). '' = redactar/borrador.
  final String message;

  /// WA-AGENT-09 — reply DINÁMICO: con [message] vacío, el motor local redacta
  /// la respuesta con el historial factual de la conversación. Sin este flag,
  /// una regla reply sin mensaje NO responde (fail-closed). El LLM solo
  /// redacta texto: destinatario, paquete y conversación siguen anclados a la
  /// notificación observada.
  final bool dynamicReply;

  final bool enabled;

  /// Marca de creación (autoridad temporal para auditar la regla).
  final DateTime createdAt;

  /// Última vez que disparó (para deduplicación/cooldown en T3.6).
  final DateTime? lastFiredAt;

  /// La regla fue creada explícitamente por el usuario (autoridad). Siempre
  /// true en T3.1: no hay creación autónoma de reglas.
  final bool createdByUser;

  const ScheduledRule({
    required this.id,
    required this.trigger,
    required this.action,
    this.message = '',
    this.dynamicReply = false,
    this.enabled = true,
    required this.createdAt,
    this.lastFiredAt,
    this.createdByUser = true,
  });

  ScheduledRule copyWith({
    RuleAction? action,
    String? message,
    bool? dynamicReply,
    bool? enabled,
    DateTime? lastFiredAt,
  }) => ScheduledRule(
    id: id,
    trigger: trigger,
    action: action ?? this.action,
    message: message ?? this.message,
    dynamicReply: dynamicReply ?? this.dynamicReply,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    lastFiredAt: lastFiredAt ?? this.lastFiredAt,
    createdByUser: createdByUser,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': triggerToJson(trigger),
    'action': action.name,
    'message': message,
    'dynamicReply': dynamicReply,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'lastFiredAt': lastFiredAt?.toIso8601String(),
    'createdByUser': createdByUser,
  };

  factory ScheduledRule.fromJson(Map<String, dynamic> m) => ScheduledRule(
    id: m['id'] as String,
    trigger: triggerFromJson((m['trigger'] as Map).cast<String, dynamic>()),
    action: RuleAction.values.byName(m['action'] as String),
    message: (m['message'] as String?) ?? '',
    dynamicReply: m['dynamicReply'] == true,
    enabled: m['enabled'] != false,
    createdAt: DateTime.parse(m['createdAt'] as String),
    lastFiredAt: m['lastFiredAt'] == null
        ? null
        : DateTime.parse(m['lastFiredAt'] as String),
    createdByUser: m['createdByUser'] != false,
  );
}
