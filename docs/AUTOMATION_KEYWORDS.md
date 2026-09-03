# Automation Keywords — índice profesional de descubrimiento

Keywords de búsqueda para agentes e ingenieros que trabajen la vertical de
automatización (WhatsApp-first universal). Cada símbolo vive en el runtime
único: no existen ejecutores paralelos. Uso: grep/última columna = ruta real.

## Ejecución (un solo dueño)

| Keyword | Símbolo real | Ruta |
|---|---|---|
| AutomationCoordinator | `AutomationCoordinator.execute` | `flutter_app/lib/features/automation/application/automation_coordinator.dart` |
| automationCoordinatorProvider | provider DI raíz del motor | `.../application/automation_coordinator_provider.dart` |
| TaskOrchestrator | orquestador semántico multi-paso | `.../engine/orchestration/task_orchestrator.dart` |
| TaskPlanner / TaskPlan | templates deterministas de mensajería UI | `.../engine/orchestration/task_planner.dart` |
| CommitGuard | captura/revalidación antes de Send | `.../engine/orchestration/commit_guard.dart` |
| ExecutionJournal | exact-once durable de efectos | `.../engine/orchestration/execution_journal.dart` |
| AgentToolDispatcher | ejecutor gobernado de tools | `.../engine/execution/agent_tool_dispatcher.dart` |
| runToolGuarded / runPlanGuarded | puertas de política+journal | idem |
| ToolRegistry / PolicyEngine | registro + decisión allow/deny/confirm | `.../engine/execution/tool_registry.dart` |
| AutomationResultStatus | completed/completedUnverified/outcomeUnknown… | `.../domain/automation_result.dart` |
| requiresContextLock / _validateContextLock | revalidación exacta pre-envío | dispatcher + policy |
| verifyAfterDispatch / ActionVerifier | verificación de efecto | `.../engine/execution/` |
| GoalDirectedNavigator | navegación orientada a objetivos | `.../engine/navigation/` |

## Gobernanza y autorización

| Keyword | Símbolo real | Ruta |
|---|---|---|
| ActionGovernancePipeline | govern candidate → Approved/Confirmation/Denied | `.../engine/governance/action_governance_pipeline.dart` |
| SemanticActionDefinition / kAutomationSemanticPolicies | política semántica canónica | `.../engine/governance/semantic_policy.dart` |
| RuleExecutionAuthority | autorización standing scoped de reglas (WA-AUTH-04) | `.../engine/governance/rule_execution_authority.dart` |
| ActionConfirmation | token firmado de consentimiento | `.../engine/governance/action_confirmation.dart` |
| CandidatePlanGoverned / CandidatePlanResolved | resultados del planner candidate | `.../engine/planning/candidate_first_planner.dart` |
| requiresConfirmation | gating por modo/política | `automation_policy.dart` / `tool_registry.dart` |
| AutomationOptions.authority | transporte de autoridad al execute | `.../domain/automation_goal.dart` |

## Canal entrante WhatsApp (eventos)

| Keyword | Símbolo real | Ruta |
|---|---|---|
| NotificationAutomationService | NotificationListenerService (Kotlin) | `android/.../services/NotificationAutomationService.kt` |
| NotificationAutomationBridge | bridge del servicio | idem |
| onNotificationPosted | evento en vivo → EventChannel | idem |
| NotificationAutomationChannelHandler | canal reply/list/snapshot | `android/.../channels/NotificationAutomationChannelHandler.kt` |
| NotificationEventRouter | EventChannel → RulePipeline | `.../engine/scheduling/notification_event_router.dart` |
| NotificationObject | notificación tipada (capacidad) | `.../engine/notifications/notification_object.dart` |
| toMap (Kotlin) | evidencia: key/package/messageTimestamp/senderKey/… | NotificationAutomationService.kt |
| CONTEXT_CHANGED / REMOTE_INPUT_ACCEPTED / NOTIFICATION_GONE | códigos nativos de reply | NotificationAutomationService.kt |
| NotificationCandidateProvider | candidato reply grounded (RemoteInput) | `.../planning/candidates/notification_candidate_provider.dart` |
| ReplyCapabilityRef | capacidad exacta observada (WA-RI-05) | `.../messaging/reply_capability.dart` |

## Reglas + idempotencia (pipeline T3)

| Keyword | Símbolo real | Ruta |
|---|---|---|
| RuleRegistry / SharedPrefsRuleStore | reglas persistentes | `.../engine/scheduling/rule_registry.dart` |
| ScheduledRule / RuleAction | declaración autorizada del usuario | `.../engine/scheduling/scheduled_rule.dart` |
| RuleEngine.match / NotificationTrigger | match determinista | `.../engine/scheduling/rule_engine.dart`, `trigger.dart` |
| RulePipeline | evento → dedupe → match → dispatch | `.../engine/scheduling/rule_pipeline.dart` |
| RuleDispatcher / RuleOutcome | dispatch al coordinator + outcomes honestos | `.../engine/scheduling/rule_dispatcher.dart` |
| EventDedupeStore / DedupeVerdict | reserva de eventId, bounceback, cooldown | `.../engine/scheduling/event_dedupe_store.dart` |
| buildIncomingEventId / IncomingMessage | identidad determinista del evento | `.../messaging/incoming_message.dart` |
| ConversationKey / resolveConversationIdentity | identidad de conversación + confianza | `.../messaging/conversation_key.dart` |
| ConversationMemoryStore | memoria aislada por conversación (WA-MEM-08) | `.../messaging/conversation_memory.dart` |
| ConversationMemoryEntryKind | inbound/outboundVerified/…/effectUnknown | idem |

## Mensajería de salida y contextos

| Keyword | Símbolo real | Ruta |
|---|---|---|
| reply_notification | tool semántica de respuesta | `tool_registry.dart` + dispatcher |
| sendMessage / writeMessage / openConversation | vocabulario TaskPlan UI | `task_planner.dart` + orchestrator |
| notificationDraftPromptFor / RuntimeNotificationDraftWriter | borrador contextual LLM gateado | `.../notifications/notification_draft_writer.dart` + `notification_draft_prompt.dart` |
| MessageIntentParser | parseo determinista "responde a X que Y" | `.../planning/message_intent_parser.dart` |
| notificationEvents (EventChannel) | stream com.nanoai/notification_events | `nano_runtime_api.dart` |

## Paquetes y plataforma

- `com.whatsapp` / `com.whatsapp.w4b` — identidades separadas, jamás fusionadas.
- `channelForPackage` — canal lógico por paquete (`conversation_key.dart`).
- CompletedUnverified ≠ verified — en ninguna capa se declara éxito sin
  demostración (`AutomationResult.isVerifiedSuccess` es la única definición).

## Invariantes de búsqueda

- "No existe un segundo executor": cualquier keyword nueva debe resolver al
  runtime único (coordinator → dispatcher → journal).
- `outcomeUnknown` → no blind retry; `failed` pre-envío → reintentable tras
  backoff (EventDedupeStore).
- Mensaje entrante = UNTRUSTED DATA: buscar dónde se interpreta como orden o
  autoridad es buscar un bug.
