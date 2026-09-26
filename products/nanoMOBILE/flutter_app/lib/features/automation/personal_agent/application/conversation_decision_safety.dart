// conversation_decision_safety.dart
//
// QUÉ HACE: Barreras de seguridad duras y precondiciones de diálogo para el Agente Personal.
// CÓMO FUNCIONA: Verifica ownership humana, modo de autonomía, umbral de identidad (0.95),
// muletillas call-center, fugas de formato interno, eco literal y Live State no verificable.
// POR QUÉ: Cumple SRP manteniendo el código estructurado en módulos < 200 líneas.

library;

import '../../engine/language/safe_conversation_repair.dart'
    show RepairCase, safeConversationRepair;
import '../../engine/messaging/conversation_key.dart' show ConversationIdentity;
import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_agent_role.dart';
import '../domain/conversation_autonomy_mode.dart';
import '../domain/conversation_decision.dart';
import 'conversation_decision_guards.dart';
import 'conversation_decision_repair_validator.dart';

part 'conversation_decision_live_state.part.dart';

abstract final class ConversationDecisionSafety {
  static ConversationDecision? evaluatePreconditions({
    required ConversationUnderstanding understanding,
    required ConversationDecisionContext context,
    required bool allowRepair,
    required ConversationDecision Function({
      required ConversationUnderstanding understanding,
      required ConversationDecisionContext context,
      required bool allowRepair,
    })
    decider,
  }) {
    // 1. Ownership humana: el dueño manda. Se retiene SIEMPRE.
    if (context.humanOwnsConversation) {
      return const ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.low,
        confidence: 0.0,
        reasons: ['ownership: humano controla la conversación'],
        action: DialogueDecisionAction.transferToOwner,
      );
    }

    // 2. Autonomía desactivada: retención inmediata.
    if (context.autonomyMode == ConversationAutonomyMode.disabled) {
      return const ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.low,
        confidence: 0.0,
        reasons: ['autonomía desactivada: el pipeline no responde'],
        action: DialogueDecisionAction.transferToOwner,
      );
    }

    // 3. Identidad débil: sin evidencia de plataforma estable no hay envío automático.
    if (context.identityConfidence <
        ConversationIdentity.safeToWriteThreshold) {
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: [
          'identidad débil (${context.identityConfidence.toStringAsFixed(2)} < ${ConversationIdentity.safeToWriteThreshold}): sin evidencia estable',
        ],
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    // 4. Prohibición de muletillas de operador en turnos personales.
    final callCenterTurn =
        context.agentRole == ConversationAgentRole.personal ||
        context.agentRole == ConversationAgentRole.general;
    if (callCenterTurn &&
        (ConversationDecisionGuards.isCallCenterPhrase(understanding.reply) ||
            (isGreetingLikeMessage(context.userText) &&
                ConversationDecisionGuards.fold(
                  understanding.reply,
                ).contains('soy nano')))) {
      final repaired = safeConversationRepair.repair(
        RepairCase.callCenterPhrase,
        reply: understanding.reply,
        userText: context.userText,
        senderName: context.senderName,
      );
      if (allowRepair &&
          repaired != null &&
          repaired.trim() != understanding.reply.trim()) {
        return ConversationDecisionRepairValidator.validate(
          understanding: understanding,
          context: context,
          repaired: repaired,
          reason: 'calidad reparada: muletilla call-center eliminada',
          decider: decider,
        );
      }
      return const ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: [
          'P0-NO-CALLCENTER: operador/identidad en turno personal/general',
        ],
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    // 5. Formato interno fugado al reply.
    if (RegExp(
      r'^(nano|respuesta|intent|relation|questions|missingfacts|requiresaction)\s*[:=]',
    ).hasMatch(ConversationDecisionGuards.fold(understanding.reply.trim()))) {
      return const ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.4,
        reasons: ['formato interno fugado al reply (prefijo de diálogo)'],
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    // 6. Detección de eco del cliente.
    if (ConversationDecisionGuards.normalizedEcho(
          understanding.reply,
        ).isNotEmpty &&
        ConversationDecisionGuards.normalizedEcho(understanding.reply) ==
            ConversationDecisionGuards.normalizedEcho(context.userText)) {
      return const ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.5,
        reasons: ['reply eco del cliente: el modelo repitió el mensaje'],
        action: DialogueDecisionAction.ignore,
      );
    }

    // 7. Pregunta redundante sobre el estado ya relatado.
    if (ConversationDecisionGuards.isRedundantStateQuestion(
      context.userText,
      understanding.reply,
    )) {
      final repaired = safeConversationRepair.repair(
        RepairCase.redundantQuestion,
        reply: understanding.reply,
        userText: context.userText,
        senderName: context.senderName,
      );
      if (allowRepair &&
          repaired != null &&
          repaired.trim() != understanding.reply.trim()) {
        return ConversationDecisionRepairValidator.validate(
          understanding: understanding,
          context: context,
          repaired: repaired,
          reason: 'calidad reparada: pregunta redundante de estado eliminada',
          decider: decider,
        );
      }
      return const ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.4,
        reasons: ['pregunta redundante sobre el estado/día ya relatado'],
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    return _evaluateLiveStateSafety(
      understanding: understanding,
      context: context,
      callCenterTurn: callCenterTurn,
      allowRepair: allowRepair,
      decider: decider,
    );
  }
}
