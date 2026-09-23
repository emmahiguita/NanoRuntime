// conversation_decision_safety.dart
//
// QUÉ HACE:
// Barreras de seguridad duras y precondiciones de diálogo para el Agente Personal.
//
// CÓMO FUNCIONA:
// - Verifica ownership humana (el bot nunca sobreescribe al dueño).
// - Evalúa el modo de autonomía y umbral de seguridad de identidad de plataforma (0.95).
// - Detecta e intercepta muletillas de call-center, fugas de formato interno y eco literal del cliente.
// - Aplica o delega reparación determinista segura cuando detecta defectos de cortesía.
//
// POR QUÉ:
// Cumple Single Responsibility Principle (SRP) manteniendo el código estructurado en módulos < 200 líneas.

library;

import '../../engine/language/safe_conversation_repair.dart' show RepairCase, safeConversationRepair;
import '../../engine/messaging/conversation_key.dart' show ConversationIdentity;
import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_agent_role.dart';
import '../domain/conversation_autonomy_mode.dart';
import '../domain/conversation_decision.dart';
import 'conversation_decision_guards.dart';
import 'conversation_decision_repair_validator.dart';

abstract final class ConversationDecisionSafety {
  static ConversationDecision? evaluatePreconditions({
    required ConversationUnderstanding understanding,
    required ConversationDecisionContext context,
    required bool allowRepair,
    required ConversationDecision Function({
      required ConversationUnderstanding understanding,
      required ConversationDecisionContext context,
      required bool allowRepair,
    }) decider,
  }) {
    final reasons = <String>[];

    // 1. Ownership humana: el dueño manda. Se retiene SIEMPRE.
    if (context.humanOwnsConversation) {
      reasons.add('ownership: humano controla la conversación');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.low,
        confidence: 0.0,
        reasons: reasons,
        action: DialogueDecisionAction.transferToOwner,
      );
    }

    // 2. Autonomía desactivada: retención inmediata.
    if (context.autonomyMode == ConversationAutonomyMode.disabled) {
      reasons.add('autonomía desactivada: el pipeline no responde');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.low,
        confidence: 0.0,
        reasons: reasons,
        action: DialogueDecisionAction.transferToOwner,
      );
    }

    // 3. Identidad débil: sin evidencia de plataforma estable no hay envío automático.
    if (context.identityConfidence < ConversationIdentity.safeToWriteThreshold) {
      reasons.add('identidad débil (${context.identityConfidence.toStringAsFixed(2)} < ${ConversationIdentity.safeToWriteThreshold}): sin evidencia estable');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: reasons,
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    // 4. Prohibición de muletillas de operador en turnos personales.
    final callCenterTurn = context.agentRole == ConversationAgentRole.personal ||
        context.agentRole == ConversationAgentRole.general;
    if (callCenterTurn &&
        (ConversationDecisionGuards.isCallCenterPhrase(understanding.reply) ||
            (isGreetingLikeMessage(context.userText) &&
                ConversationDecisionGuards.fold(understanding.reply).contains('soy nano')))) {
      final repaired = safeConversationRepair.repair(
        RepairCase.callCenterPhrase,
        reply: understanding.reply,
        userText: context.userText,
        senderName: context.senderName,
      );
      if (allowRepair && repaired != null && repaired.trim() != understanding.reply.trim()) {
        return ConversationDecisionRepairValidator.validate(
          understanding: understanding,
          context: context,
          repaired: repaired,
          reason: 'calidad reparada: muletilla call-center eliminada',
          decider: decider,
        );
      }
      reasons.add('P0-NO-CALLCENTER: operador/identidad en turno personal/general');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: reasons,
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    // 5. Formato interno fugado al reply.
    if (RegExp(r'^(nano|respuesta|intent|relation|questions|missingfacts|requiresaction)\s*[:=]')
        .hasMatch(ConversationDecisionGuards.fold(understanding.reply.trim()))) {
      reasons.add('formato interno fugado al reply (prefijo de diálogo)');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.4,
        reasons: reasons,
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    // 6. Detección de eco del cliente.
    if (ConversationDecisionGuards.normalizedEcho(understanding.reply).isNotEmpty &&
        ConversationDecisionGuards.normalizedEcho(understanding.reply) ==
            ConversationDecisionGuards.normalizedEcho(context.userText)) {
      reasons.add('reply eco del cliente: el modelo repitió el mensaje');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.5,
        reasons: reasons,
        action: DialogueDecisionAction.ignore,
      );
    }

    // 7. Pregunta redundante sobre el estado ya relatado.
    if (ConversationDecisionGuards.isRedundantStateQuestion(context.userText, understanding.reply)) {
      final repaired = safeConversationRepair.repair(
        RepairCase.redundantQuestion,
        reply: understanding.reply,
        userText: context.userText,
        senderName: context.senderName,
      );
      if (allowRepair && repaired != null && repaired.trim() != understanding.reply.trim()) {
        return ConversationDecisionRepairValidator.validate(
          understanding: understanding,
          context: context,
          repaired: repaired,
          reason: 'calidad reparada: pregunta redundante de estado eliminada',
          decider: decider,
        );
      }
      reasons.add('pregunta redundante sobre el estado/día ya relatado');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.4,
        reasons: reasons,
        action: DialogueDecisionAction.prepareDraft,
      );
    }

    return null;
  }
}
