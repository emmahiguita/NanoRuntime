// Orquesta respuestas verificadas y conserva el estado antes de devolverlas.
// El envío pertenece al dispatcher existente: no crea una segunda cola sin consumidor.
library;

import '../actions/commercial_action_parser.dart';
import '../actions/commercial_structured_action.dart';
import '../business_conversation_models.dart';
import '../business_facts.dart';
import '../policy/commercial_action_policy_engine.dart';
import '../policy/commercial_policy_tier.dart';
import '../queue/durable_inbox_store.dart';
import '../queue/durable_outbox_queue.dart';
import '../state/commercial_conversation_state_store.dart';
import '../state/commercial_funnel_stage.dart';
import '../validation/business_response_validator.dart';
import '../validation/business_validation_result.dart';
import '../../messaging/core/nano_incoming_message.dart';
import '../../messaging/core/nano_outgoing_message.dart';
import 'nano_business_turn_result.dart';
export 'nano_business_turn_result.dart';
import 'nano_business_turn_resolver.dart';
import 'business_turn_serial_queue.dart';

class NanoBusinessRuntime {
  final BusinessFacts facts;
  final DurableInboxStore inboxStore;
  // Compatibilidad de inyección: no se encola hasta tener un consumidor conectado.
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
  }) : validator = BusinessResponseValidator(facts),
       policyEngine = CommercialActionPolicyEngine(facts);

  /// Conserva la identidad universal del mensaje, no la del contenedor Android.
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

  /// Serializa lecturas/escrituras del inbox compartido dentro de este isolate.
  Future<NanoBusinessTurnResult?> processTurn({
    required String eventId,
    required String conversationId,
    required String incomingText,
    String? rawModelStructuredOutput,
    BusinessTurnReply? factualReply,
    String channel = 'generic',
  }) => BusinessTurnSerialQueue.run(
    () => _resolveTurn(
      eventId,
      conversationId,
      incomingText,
      rawModelStructuredOutput,
      factualReply,
    ),
  );

  Future<NanoBusinessTurnResult?> _resolveTurn(
    String eventId,
    String conversationId,
    String incomingText,
    String? modelOutput,
    BusinessTurnReply? factualReply,
  ) async {
    if (eventId.isEmpty || conversationId.isEmpty) {
      throw ArgumentError(
        'El turno requiere identidad de mensaje y conversación.',
      );
    }
    var state = await stateStore.load(conversationId);
    if (await inboxStore.isProcessed(eventId)) {
      return NanoBusinessTurnResult(
        replyText: '',
        updatedState: state,
        isDuplicate: true,
      );
    }
    final injection = policyEngine.detectPromptInjection(incomingText);
    final action = modelOutput != null && modelOutput.isNotEmpty
        ? actionParser.parse(modelOutput)
        : turnResolver.resolveHeuristicAction(incomingText, facts, state);
    if (!injection && action == null && factualReply == null) return null;

    var reply = factualReply?.text ?? '';
    var suggestions = factualReply?.suggestions ?? const <String>[];
    var human = factualReply?.needsHuman == true;
    var confirmation = false;
    String? reason;
    if (injection) {
      reply =
          'No puedo modificar precios ni políticas del catálogo por un mensaje.';
      human = true;
      reason = 'Solicitud de cambio no autorizado';
    } else if (action != null) {
      final policy = policyEngine.evaluate(action);
      final validation = validator.validate(action);
      // Las consultas informativas usan el resolver con frases editables.
      final editableQuery =
          action is PriceQueryAction ||
          action is CatalogQueryAction ||
          action is PolicyQueryAction;
      switch (validation) {
        case AcceptedBusinessValidation accepted:
          if (!editableQuery || reply.isEmpty) {
            reply = accepted.formattedReply;
            suggestions = accepted.suggestions;
          }
          confirmation = policy.tier == CommercialPolicyTier.needsConfirmation;
          // Una propuesta no altera carrito ni estado de compra sin confirmación.
          if (policy.allowed && !confirmation && !human) {
            state = turnResolver.updateStateOnSuccess(state, action, accepted);
          }
        case RejectedBusinessValidation rejected:
          if (!editableQuery || reply.isEmpty) reply = rejected.fallbackReply;
        case EscalatedBusinessValidation escalated:
          reply =
              action is EscalateToHumanAction &&
                  factualReply?.needsHuman == true
              ? factualReply!.text
              : escalated.noticeToCustomer;
          human = true;
          reason = escalated.reason;
      }
      human =
          human ||
          policy.tier == CommercialPolicyTier.needsHuman ||
          policy.tier == CommercialPolicyTier.blocked ||
          !policy.allowed;
      reason ??= human ? policy.reason : null;
    }
    if (reply.trim().isEmpty) return null;
    if (human) {
      state = state.copyWith(
        stage: CommercialFunnelStage.escalatedHuman,
        isHumanEscalated: true,
        escalationReason: reason,
      );
    }
    state = state.copyWith(lastInteraction: DateTime.now());
    // No devuelve éxito si la base de datos rechazó la escritura.
    if (!await stateStore.save(state)) {
      throw StateError('No se pudo guardar el estado comercial.');
    }
    await inboxStore.markProcessed(
      eventId: eventId,
      conversationId: conversationId,
      content: incomingText,
    );
    return NanoBusinessTurnResult(
      replyText: reply,
      isEscalatedToHuman: human,
      requiresConfirmation: confirmation,
      escalatedReason: reason,
      suggestions: suggestions,
      updatedState: state,
      outgoingMessage: NanoOutgoingMessage(
        id: 'out_$eventId',
        conversationId: conversationId,
        text: reply,
      ),
    );
  }
}
