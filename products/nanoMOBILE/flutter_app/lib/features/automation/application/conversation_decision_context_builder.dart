// conversation_decision_context_builder.dart
//
// QUÉ HACE:
// Construye el ConversationDecisionContext canónico para un turno conversacional entrante,
// evaluando ownership humano, rol asignado, estado de contacto y modo de autonomía.
//
// CÓMO FUNCIONA:
// 1. Resuelve la identidad y consulta el almacén de ownership durable.
// 2. Determina si el humano tiene control activo con timeout de inactividad de 30 minutos.
// 3. Sincroniza el modo de autonomía (eleva 'suggestions' a 'autonomous' si el agente general está en autónomo).
// 4. Integra hechos de negocio, relaciones personales y reglas activas para emitir el contexto final.
//
// POR QUÉ:
// Aplica Clean Architecture y Single Responsibility Principle (SRP) manteniendo el código
// modular, comprobable y estrictamente por debajo de 200 líneas de código.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart'
    show AgentAutomationMode;
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/conv_turn_state.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart'
    show resolveConversationIdentity;
import 'package:nanoai/features/automation/engine/agent_dependencies.dart'
    show conversationAssignmentStoreProvider;
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_ownership_policy.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'automation_coordinator_provider.dart';

/// Helper canónico para construir el contexto de decisión factual del turno.
ConversationDecisionContext buildConversationDecisionContext(
  Ref ref,
  NotificationObject notif,
) {
  final identity = resolveConversationIdentity(notif);
  final store = ref.read(conversationOwnershipStoreProvider);
  // La autorización solo usa la identidad técnica resuelta por Android.
  // Un nombre visible puede repetirse y nunca debe habilitar otro chat.
  final ownership = store.ownershipFor(identity.key.id);
  final entry = ref.read(conversationStateNotifierProvider)[identity.key.id];
  final hasActiveProduct =
      entry != null && entry.product != null && entry.topicStatus == 'active';
  final hasPendingQuestion = entry != null && entry.pendingQuestion.isNotEmpty;

  final routing = routeConversationAgent(
    messageText: notif.text,
    facts: ref.read(businessFactsNotifierProvider),
    hasRelationship: ref
        .read(personaContextProvider)
        .hasRelationshipFor(
          notif.sender,
          conversationId: resolveConversationIdentity(notif).key.id,
        ),
    hasActiveProduct: hasActiveProduct,
    ownerName: ref.read(personaContextProvider).ownerName,
    hasPendingQuestion: hasPendingQuestion,
    isBusinessChannel: notif.packageName == MessagingPackage.whatsappBusiness,
  );

  final assignedAgent = ref
      .read(conversationAssignmentStoreProvider)
      .agentForConversationId(identity.key.id);
  final effectiveRole = switch (assignedAgent) {
    ConversationAgentId.personal => ConversationAgentRole.personal,
    ConversationAgentId.business =>
      routing.role == ConversationAgentRole.support
          ? ConversationAgentRole.support
          : ConversationAgentRole.sales,
  };

  final settings = ref.read(settingsProvider);
  final rawMode = ConversationAutonomyModeName.fromName(
    settings.waAutonomyMode,
  );
  final mode =
      (settings.agentAutomationMode == AgentAutomationMode.autonomous &&
          rawMode == ConversationAutonomyMode.suggestions)
      ? ConversationAutonomyMode.autonomous
      : rawMode;

  final targetMode = settings.waTargetContactsMode;
  // La interfaz consulta esta misma política, así el estado visible coincide
  // con el bloqueo o la autorización aplicados por el pipeline.
  final effectiveHumanOwns = ConversationOwnershipPolicy.humanOwns(
    targetContactsMode: targetMode,
    ownership: ownership,
  );

  debugPrint(
    '[agent] agente=${assignedAgent.name} rol=${effectiveRole.name} modo=${mode.name} '
    'targetMode=$targetMode humanOwns=$effectiveHumanOwns '
    '${routing.reasons.join(' | ')}',
  );

  return ConversationDecisionContext(
    humanOwnsConversation: effectiveHumanOwns,
    identityConfidence: identity.confidence,
    autonomyMode: mode,
    agentRole: effectiveRole,
    agentId: assignedAgent,
    userText: notif.text,
    senderName: notif.sender,
  );
}
