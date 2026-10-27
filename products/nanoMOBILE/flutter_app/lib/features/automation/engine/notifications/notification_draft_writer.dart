/// Redacción contextual de una respuesta a notificación (A14.7).
/// Motor opcional: sin inferencia real no fabrica respuestas. Aísla datos no confiables.
library;

import 'dart:async';
import 'package:nanoai/core/services/execution_budget.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:nanoai/core/models/catalog_models.dart'
    show ModelBackendType, NeuralCatalog;
import 'package:nanoai/core/services/generative_inference_port.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_identity_context.dart';
import 'package:nanoai/core/services/personal_language_policy.dart';
import 'package:nanoai/core/services/personal_prompt_policy.dart';
import 'package:nanoai/core/services/conversation_reply_quality.dart';
import '../../personal_agent/domain/personal_live_context.dart';
import 'native_conversation_history.dart';
import '../language/runtime_personal_live_context.dart';
import '../../personal_agent/domain/conversation_agent_role.dart'
    show
        ConversationAgentRole,
        ConversationAgentRouting,
        isCorrectionMessage,
        isGreetingLikeMessage,
        isLiveStateQuestion,
        productMentionedWithoutCommerce;
import '../conversation/personal_conversation_diagnostic.dart';
import '../messaging/conversation_durable_context.dart';
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_agent.dart';
import '../messaging/conversation_memory.dart'
    show
        ConversationMemoryEntry,
        ConversationMemoryEntryKind,
        ConversationMemoryStore;
import '../model/cold_start_retry.dart';
import '../model/inference_telemetry.dart' show InferenceTelemetry;
import '../../personal_agent/application/personal_turn_state_access.dart'
    show PersonalTurnStateAccess;
import '../../personal_agent/domain/open_loop_detector.dart'
    show OpenLoopDetector;
import '../scheduling/messaging_metrics.dart';
import '../messaging/incoming_message.dart';
import 'conversation_understanding.dart';
import 'conversation_agent_contract.dart';
import 'notification_draft_prompt.dart';
import 'cloud_turn_context.dart';
import 'media_prompt_budget.dart';
import 'notification_object.dart';
import 'conversation_social_window.dart';
import '../language/temporal_location_context.dart';
import '../language/turn_complexity_classifier.dart'
    show turnComplexityClassifier;

part 'notification_draft_writer_result.part.dart';
part 'notification_draft_writer_queue.part.dart';
part 'notification_draft_writer_context.part.dart';
part 'notification_draft_writer_prompt.part.dart';
part 'notification_draft_writer_prepared.part.dart';
part 'notification_draft_writer_capacity.part.dart';
part 'notification_draft_writer_personal_prompt.part.dart';
part 'notification_draft_writer_generation.part.dart';
part 'notification_draft_writer_draft.part.dart';
part 'notification_draft_writer_response.part.dart';
part 'notification_draft_writer_trace.part.dart';

/// Coordinador de redacción contextual de respuestas (Local Open Source + Multi-API Cloud).
///
/// - **QUÉ HACE:** Encola turnos, construye el contexto conversacional real y delega
///   la inferencia a LiteRT-LM o al puerto Multi-API (Groq + Gemini).
/// - **CÓMO FUNCIONA:** Serializa las peticiones por conversación, inyecta persona/agenda
///   en vivo y conserva la caché KV nativa entre turnos consecutivos.
/// - **POR QUÉ:** Garantiza respuestas rápidas, naturales y sin cruce de sesiones.
final class RuntimeNotificationDraftWriter {
  RuntimeNotificationDraftWriter({
    required LLMEngineClient client,
    required bool Function() llmAllowed,
    required Future<bool> Function(String? modelPath) ensureReady,
    required String? Function() modelPath,
    Future<void> Function()? afterDraft,
    required bool Function() styleEnabled,
    required String Function() styleText,
    String Function(String messageText)? businessBlock,
    String Function()? toneBlock,
    String Function(String conversationId, String messageText)?
    clientContextFor,
    Future<String> Function(
      String conversationId,
      String messageText,
      String sender,
      String role,
    )?
    personaBlock,
    ConversationAgentRouting Function(
      String conversationId,
      String messageText,
      String sender,
      String? packageName,
    )?
    routeFor,
    ConversationAgentId Function(String conversationId, String packageName)?
    agentFor,
    ConversationMemoryStore? memory,
    PersonalLiveContext? liveContext,
    GenerativeInferencePort? cloudInferencePort,
    Future<void> Function({
      required String input,
      required String response,
      required String provider,
    })?
    externalResponseLearner,
    bool Function(String conversationId, String sender)?
    externalResponseLearningAllowed,
  }) : _client = client,
       _llmAllowed = llmAllowed,
       _ensureReady = ensureReady,
       _modelPath = modelPath,
       _afterDraft = afterDraft,
       _styleEnabled = styleEnabled,
       _styleText = styleText,
       _businessBlock = businessBlock,
       _toneBlock = toneBlock,
       _clientContextFor = clientContextFor,
       _personaBlock = personaBlock,
       _routeFor = routeFor,
       _agentFor = agentFor,
       _memory = memory,
       _liveContext =
           liveContext ?? RuntimePersonalLiveContext(allowDeclaredAgenda: true),
       _externalResponseLearner = externalResponseLearner,
       _externalResponseLearningAllowed = externalResponseLearningAllowed,
       _cloudInferencePort =
           cloudInferencePort ?? CloudGenerativeInferenceAdapter();

  final LLMEngineClient _client;
  final GenerativeInferencePort? _cloudInferencePort;
  final bool Function() _llmAllowed;
  final Future<bool> Function(String? modelPath) _ensureReady;
  final String? Function() _modelPath;
  final Future<void> Function()? _afterDraft;
  final bool Function() _styleEnabled;
  final String Function() _styleText;
  final String Function(String messageText)? _businessBlock;
  final String Function()? _toneBlock;
  final String Function(String conversationId, String messageText)?
  _clientContextFor;
  final Future<String> Function(
    String conversationId,
    String messageText,
    String sender,
    String role,
  )?
  _personaBlock;
  final ConversationAgentRouting Function(
    String conversationId,
    String messageText,
    String sender,
    String? packageName,
  )?
  _routeFor;
  final ConversationAgentId Function(String conversationId, String packageName)?
  _agentFor;
  final ConversationMemoryStore? _memory;
  final PersonalLiveContext _liveContext;
  final Future<void> Function({
    required String input,
    required String response,
    required String provider,
  })?
  _externalResponseLearner;
  final bool Function(String conversationId, String sender)?
  _externalResponseLearningAllowed;

  static final Map<String, Future<NotificationDraftResult?>> _inFlight = {};
  static final Map<String, String> _latestFlightKeyByConv = {};
  static Future<void> _draftTail = Future<void>.value();
  static int _queueDepth = 0;
  static const _maxQueueDepth = 64;

  static String _flightFingerprint(NotificationObject n) =>
      IncomingMessage.fromNotification(n).eventId;

  Future<NotificationDraftResult?> call(NotificationObject notification) =>
      _enqueueNotificationDraft(this, notification);
}
