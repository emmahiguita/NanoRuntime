// nano_business_runtime.dart
//
// QUÉ HACE:
// Orquestador maestro agnóstico del runtime comercial de Nano Negocio.
// Conecta en un solo flujo determinista y seguro las 5 capas de producción:
// NanoIncomingMessage → Inbox Durable → Estado → Validador de Verdad → Motor de Políticas → NanoOutgoingMessage.
//
// CÓMO FUNCIONA:
// - Desecha mensajes duplicados de forma idempotente con DurableInboxStore.
// - Carga el estado del embudo comercial (CommercialConversationStateStore).
// - Detecta y bloquea intentos de prompt injection.
// - Parsea la acción estructurada y la valida contra BusinessFacts (Truth Boundary).
// - Emite un NanoOutgoingMessage agnóstico y encola en DurableOutboxQueue.
//
// POR QUÉ:
// Aplica la regla <channel_agnostic_messaging>: el runtime opera sobre modelos universales.

library;

import '../actions/commercial_action_parser.dart';
import '../business_facts.dart';
import '../policy/commercial_action_policy_engine.dart';
import '../policy/commercial_policy_tier.dart';
import '../queue/durable_inbox_store.dart';
import '../queue/durable_outbox_message.dart';
import '../queue/durable_outbox_queue.dart';
import '../state/commercial_conversation_state.dart';
import '../state/commercial_conversation_state_store.dart';
import '../state/commercial_funnel_stage.dart';
import '../validation/business_response_validator.dart';
import '../validation/business_validation_result.dart';
import '../../messaging/core/nano_incoming_message.dart';
import '../../messaging/core/nano_outgoing_message.dart';
import 'nano_business_turn_resolver.dart';

final class NanoBusinessTurnResult {
  final String replyText;
  final bool isEscalatedToHuman;
  final String? escalatedReason;
  final List<String> suggestions;
  final CommercialConversationState updatedState;
  final NanoOutgoingMessage? outgoingMessage;

  const NanoBusinessTurnResult({
    required this.replyText,
    this.isEscalatedToHuman = false,
    this.escalatedReason,
    this.suggestions = const [],
    required this.updatedState,
    this.outgoingMessage,
  });
}

class NanoBusinessRuntime {
  final BusinessFacts facts;
  final DurableInboxStore inboxStore;
  final DurableOutboxQueue outboxQueue;
  final CommercialConversationStateStore stateStore;
  final CommercialActionParser actionParser;
  final BusinessResponseValidator validator;
  final CommercialActionPolicyEngine policyEngine;
  final NanoBusinessTurnResolver turnResolver;

  NanoBusinessRuntime({
    required this.facts,
    this.inboxStore = const DurableInboxStore(),
    this.outboxQueue = const DurableOutboxQueue(),
    this.stateStore = const CommercialConversationStateStore(),
    this.actionParser = const CommercialActionParser(),
    this.turnResolver = const NanoBusinessTurnResolver(),
  })  : validator = BusinessResponseValidator(facts),
        policyEngine = CommercialActionPolicyEngine(facts);

  /// Procesa un mensaje entrante universal (NanoIncomingMessage).
  Future<NanoBusinessTurnResult?> processIncomingMessage(
    NanoIncomingMessage message, {
    String? rawModelStructuredOutput,
  }) => processTurn(
    eventId: message.id,
    conversationId: message.conversationId,
    incomingText: message.text,
    rawModelStructuredOutput: rawModelStructuredOutput,
    channel: message.channel.name,
  );

  /// Procesa un turno de mensajería comercial independiente del canal.
  Future<NanoBusinessTurnResult?> processTurn({
    required String eventId,
    required String conversationId,
    required String incomingText,
    String? rawModelStructuredOutput,
    String channel = 'generic',
  }) async {
    // 1. Idempotencia en Durable Inbox
    if (await inboxStore.isProcessed(eventId)) return null;
    await inboxStore.markProcessed(
      eventId: eventId,
      conversationId: conversationId,
      content: incomingText,
    );

    // 2. Cargar estado de la conversación
    var state = await stateStore.load(conversationId);

    // 3. Filtro contra Prompt Injection
    if (policyEngine.detectPromptInjection(incomingText)) {
      const blocked = 'No es posible modificar políticas ni precios del catálogo. ¿Deseas consultar productos oficiales?';
      await _enqueueOutbox(conversationId, blocked, channel);
      return NanoBusinessTurnResult(replyText: blocked, updatedState: state);
    }

    // 4. Obtener acción estructurada (SLM o Heurística)
    final action = rawModelStructuredOutput != null && rawModelStructuredOutput.isNotEmpty
        ? actionParser.parse(rawModelStructuredOutput)
        : turnResolver.resolveHeuristicAction(incomingText, facts, state);

    // 5. Evaluación de Políticas y Verdad
    final policyResult = policyEngine.evaluate(action);
    final validation = validator.validate(action);

    // 6. Resolver respuesta y transición de estados
    String finalReply;
    bool isEscalated = false;
    String? escalationReason;
    List<String> suggestions = [];

    switch (validation) {
      case AcceptedBusinessValidation accepted:
        finalReply = accepted.formattedReply;
        suggestions = accepted.suggestions;
        state = turnResolver.updateStateOnSuccess(state, action, accepted);
      case RejectedBusinessValidation rejected:
        finalReply = rejected.fallbackReply;
      case EscalatedBusinessValidation escalated:
        finalReply = escalated.noticeToCustomer;
        isEscalated = true;
        escalationReason = escalated.reason;
        state = state.copyWith(
          stage: CommercialFunnelStage.escalatedHuman,
          isHumanEscalated: true,
          escalationReason: escalated.reason,
        );
    }

    if (policyResult.tier == CommercialPolicyTier.needsHuman && !isEscalated) {
      isEscalated = true;
      escalationReason = policyResult.reason;
      state = state.copyWith(
        stage: CommercialFunnelStage.escalatedHuman,
        isHumanEscalated: true,
        escalationReason: policyResult.reason,
      );
    }

    // 7. Persistir estado, crear NanoOutgoingMessage y encolar en Outbox
    state = state.copyWith(lastInteraction: DateTime.now());
    await stateStore.save(state);
    final outgoing = NanoOutgoingMessage(
      id: 'out_${conversationId}_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      text: finalReply,
    );
    await _enqueueOutbox(conversationId, finalReply, channel);

    return NanoBusinessTurnResult(
      replyText: finalReply,
      isEscalatedToHuman: isEscalated,
      escalatedReason: escalationReason,
      suggestions: suggestions,
      updatedState: state,
      outgoingMessage: outgoing,
    );
  }

  Future<void> _enqueueOutbox(String conversationId, String text, String channel) async {
    final message = DurableOutboxMessage(
      id: '${conversationId}_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      channel: channel,
      text: text,
      nextAttemptAt: DateTime.now(),
    );
    await outboxQueue.enqueue(message);
  }
}
