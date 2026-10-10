// personal_action_policy.dart
//
// QUÉ HACE:
// Define la taxonomía y política de decisión para el Agente Personal de NanoAI.
//
// CÓMO FUNCIONA:
// - Desacopla la intención del mensaje de la acción a ejecutar.
// - Implementa la política de SILENT (silencio inteligente), AUTO_REPLY, SUGGEST_REPLY y REQUIRE_HUMAN.
// - Integra soporte estructurado para dominios de alto riesgo (empleo, legal, bancario).
//
// POR QUÉ:
// Asegura que Nano Personal actúe como un asistente leal y prudente, sabiendo
// cuándo responder, cuándo callar y cuándo escalar la conversación al dueño.

library;

import 'recruitment_event.dart';

/// Acciones que el Agente Personal puede determinar ante un turno entrante.
enum PersonalAction {
  /// Silencio inteligente (turno cerrado, reacción emoji, sticker de acuse).
  silent,

  /// Respuesta automática directa (saludos, preguntas factuales de bajo riesgo).
  autoReply,

  /// Sugerencia de borrador para revisión o edición del usuario.
  suggestReply,

  /// Notificación informativa al usuario sin detener el flujo general.
  notifyHuman,

  /// Detención total de autonomía en el chat y escalamiento urgente al usuario.
  requireHuman,

  /// Transcripción de nota de voz sin respuesta automática inmediata.
  transcribe,
}

/// Dominios semánticos del mensaje para ponderar riesgo y consecuencia.
enum PersonalDomain {
  recruitment,
  banking,
  security2fa,
  legal,
  medical,
  commerce,
  support,
  social,
  general,
}

/// Intención clasificada del turno.
enum PersonalIntent {
  jobProcessUpdate,
  interviewInvitation,
  bankAlert,
  otpCode,
  legalNotice,
  greeting,
  socialAcknowledgement,
  socialInquiry,
  generalInquiry,
  unknown,
}

/// Estado conversacional del turno entre el usuario y el contacto.
enum PersonalTurnState {
  openGreeting,
  openQuestion,
  waitingForUser,
  resolved,
  socialClosing,
  unknown,
}

/// Decisión final producida por el analizador personal.
final class PersonalDecision {
  final PersonalDomain domain;
  final PersonalIntent intent;
  final PersonalTurnState turnState;
  final PersonalAction action;
  final bool requiresHuman;
  final String reason;
  final RecruitmentEvent? recruitmentEvent;

  const PersonalDecision({
    required this.domain,
    required this.intent,
    required this.turnState,
    required this.action,
    this.requiresHuman = false,
    required this.reason,
    this.recruitmentEvent,
  });

  bool get isSilent => action == PersonalAction.silent;
  bool get isAutoReply => action == PersonalAction.autoReply;
  bool get isRequireHuman => action == PersonalAction.requireHuman || requiresHuman;
}
