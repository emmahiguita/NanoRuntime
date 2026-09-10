import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/device_metrics.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/language/language_assist.dart';
import 'package:nanoai/features/automation/engine/language/pragmatic_fast_path.dart';
import 'package:nanoai/features/automation/engine/messaging/conv_turn_state.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart'
    show resolveConversationIdentity;
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall, ToolExecutionStatus, ToolOutcome;
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_decomposer.dart';
import 'package:nanoai/features/automation/engine/orchestration/commit_guard.dart';
import 'package:nanoai/features/automation/engine/orchestration/execution_journal.dart'
    show ExecutionJournalEntry;
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_plan.dart'
    show TaskActionResult, TaskActionStatus;
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show defaultDeterministicCatalog;
import 'package:nanoai/features/automation/engine/perception/mux/perception_contracts.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/surface_resolvers.dart';
import 'package:nanoai/features/automation/engine/perception/search_result_resolver.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_ownership_store.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:nanoai/features/automation/engine/scheduling/contact_rate_limiter.dart';
import 'package:nanoai/features/automation/engine/scheduling/event_dedupe_store.dart';
import 'package:nanoai/features/automation/engine/scheduling/burst_turn_gate.dart';
import 'package:nanoai/features/automation/engine/scheduling/notification_event_router.dart';
import 'package:nanoai/features/automation/engine/scheduling/turn_supersede_guard.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_engine.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_pipeline.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';
import 'package:nanoai/features/automation/engine/scheduling/time_tick_scheduler.dart';
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';
import 'package:nanoai/features/automation/engine/messaging/pending_reply.dart';
import 'package:nanoai/features/automation/engine/messaging/pending_reply_store.dart';
import 'package:nanoai/features/automation/engine/storage/automation_db_store_client.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';

import '../domain/automation_goal.dart' show AutomationOptions;
import '../ledger/action_ledger_provider.dart';
import 'automation_coordinator.dart';
import 'automation_planner_provider.dart';

/// Coordinator del módulo con el planner LLM REAL inyectado — el motor
/// AUTÓNOMO reutilizable. Las fuentes de objetivo (chat, notificaciones, voz,
/// eventos, scheduler, C10+) consumen este provider para invocar el MISMO
/// motor con `execute(goal)`. Es la fuente de verdad de la DI del módulo.
final Provider<AutomationCoordinator>
automationCoordinatorProvider = Provider<AutomationCoordinator>((ref) {
  // Observación de la pantalla actual (Accessibility → ScreenGraph). Fuente
  // ÚNICA del snapshot para los resolvers de superficie y la verificación de
  // envío, evitando duplicar el boilerplate snapshot→ScreenGraph.
  Future<ScreenGraph?> currentGraph() async {
    final snap = await ref.read(agentExecutorProvider).snapshot();
    if (snap == null || snap.isEmpty) return null;
    return ScreenGraph.fromSnapshot(snap);
  }

  TaskActionResult taskActionFrom(ToolCall call, ToolOutcome outcome) {
    if (outcome.needsConfirmation) {
      return TaskActionResult(
        status: TaskActionStatus.needsConfirmation,
        reason: outcome.feedback,
        actionSignature: call.confirmationSignature,
      );
    }
    final status = switch (outcome.executionStatus) {
      ToolExecutionStatus.completed => TaskActionStatus.completed,
      ToolExecutionStatus.completedUnverified =>
        TaskActionStatus.completedUnverified,
      ToolExecutionStatus.outcomeUnknown => TaskActionStatus.outcomeUnknown,
      ToolExecutionStatus.failed => TaskActionStatus.failed,
      ToolExecutionStatus.notExecuted => TaskActionStatus.denied,
    };
    return TaskActionResult(status: status, reason: outcome.feedback);
  }

  Future<TaskActionResult> runTaskTool(
    ToolCall call, {
    String? confirmedActionSignature,
    String? semanticAction,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final dispatcher = ref.read(agentDispatcherProvider);
    final confirmed = confirmedActionSignature == call.confirmationSignature;
    final ownerExecutionId = executionId ?? executionIntent?.runId;
    final outcome = semanticAction == null
        ? await dispatcher.runToolGuarded(
            call,
            confirmed: confirmed,
            executionId: ownerExecutionId,
          )
        : await dispatcher.runSemanticToolGuarded(
            call,
            semanticAction: semanticAction,
            confirmed: confirmed,
            executionId: ownerExecutionId,
            executionIntent: executionIntent,
          );
    return taskActionFrom(call, outcome);
  }

  return AutomationCoordinator(
    dispatcher: ref.watch(agentDispatcherProvider),
    mode: () => ref.read(settingsProvider).agentAutomationMode,
    cache: ref.watch(experienceCacheProvider),
    flowExecutor: ref.watch(nanoFlowExecutorProvider),
    ledger: ref.watch(actionLedgerProvider),
    planner: ref.watch(llmAutomationPlannerProvider),
    verifyGoal: ref.watch(goalVerifierProvider).verify,
    catalog: defaultDeterministicCatalog,
    objectMemory: const NanoObjectMemory(),
    // A13.6: compartir la instancia de memoria actualizada con el PerceptionMux
    // (vía el notifier), eliminando el split-brain.
    onMemoryUpdate: (m) => ref.read(objectMemoryProvider.notifier).replace(m),
    // A8: percepción orquestada real (accesibilidad vía ScreenGraph).
    perceptionMux: ref.watch(perceptionMuxProvider),
    // A2: resuelve "abre <app>" con package REAL del PackageManager.
    appLaunch: ref.watch(appLaunchResolverProvider),
    // A13.5: planificador Candidate-First de producción (0 LLM goals conocidos).
    candidateFirst: ref.watch(candidateFirstPlannerProvider),
    // A15.0: orquestador cross-app multi-paso con data flow tipado (0 LLM).
    taskPlanner: const TaskPlanner(),
    taskOrchestrator: TaskOrchestrator(
      listNotifications: () =>
          NanoRuntimeApi.instance.listActiveNotifications(),
      openUrl: (url, {confirmedActionSignature, semanticAction}) => runTaskTool(
        ToolCall(tool: 'open_url', text: url),
        confirmedActionSignature: confirmedActionSignature,
        semanticAction: semanticAction,
      ),
      writeFile: (path, content, {confirmedActionSignature, semanticAction}) =>
          runTaskTool(
            ToolCall(
              tool: 'linux.writeFile',
              text: path,
              args: {'content': content},
            ),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
          ),
      // A15.4: fuentes UI (delegan al dispatcher, que ya tiene governance).
      launchApp: (appName, {confirmedActionSignature, semanticAction}) async {
        // Destino de sistema primero (Ajustes/Bluetooth/WiFi → open_system
        // allowlisted). "Ve a Ajustes y busca X" NO es launch_app: es un intent
        // oficial de sistema, no una app instalada.
        final known = defaultDeterministicCatalog.forGoal('abre $appName');
        if (known != null &&
            known.steps.length == 1 &&
            known.steps.single.tool == 'open_system') {
          final dest = known.steps.single.destinationArg;
          if (dest == null) {
            return const TaskActionResult(
              status: TaskActionStatus.failed,
              reason: 'destino de sistema sin identificador',
            );
          }
          return runTaskTool(
            ToolCall(tool: 'open_system', args: {'destination': dest}),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
          );
        }
        // Resolver nombre de app → packageName real (el dispatcher launch_app
        // espera package, no nombre). Evita "whatsapp" inválido.
        final catalog = ref.read(installedAppCatalogProvider);
        final match = await catalog.findApp(appName);
        // Seguridad: ante AppMatchAmbiguous NO se elige `candidates.first` a
        // ciegas (WhatsApp vs WhatsApp Business). Solo se lanza si la resolución
        // es ÚNICA; la ambigüedad la resuelve Candidate-First (Koog) aguas
        // arriba con evidencia contextual, o se reporta sin lanzar.
        if (match is AppMatchAmbiguous) {
          final labels = match.candidates
              .map((candidate) => candidate.label)
              .toSet()
              .join(', ');
          return TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'app ambigua: $labels',
          );
        }
        if (match is! AppMatchResolved) {
          return TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'app "$appName" no encontrada en el catálogo lanzable',
          );
        }
        final pkg = match.app.packageName;
        return runTaskTool(
          ToolCall(tool: 'launch_app', args: {'packageName': pkg}),
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: semanticAction,
        );
      },
      tap:
          (
            selector, {
            confirmedActionSignature,
            semanticAction,
            executionId,
            executionIntent,
          }) => runTaskTool(
            ToolCall(tool: 'tap', selector: selector),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
            executionId: executionId,
            executionIntent: executionIntent,
          ),
      writeText: (selector, text, {confirmedActionSignature, semanticAction}) =>
          runTaskTool(
            ToolCall(tool: 'write', selector: selector, text: text),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
          ),
      submitInput: ({expectedPackageName = ''}) async {
        final result = await NanoRuntimeApi.instance.agentSubmitFocusedInput(
          expectedPackageName: expectedPackageName,
        );
        if (result == null) {
          return const TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'canal IME no disponible',
          );
        }
        if (result['ok'] != true) {
          return TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'submit IME rechazado: ${result['code'] ?? 'UNKNOWN'}',
          );
        }
        return const TaskActionResult(
          status: TaskActionStatus.completedUnverified,
          reason: 'acción Buscar/Ir aceptada por el campo enfocado',
        );
      },
      back: ({confirmedActionSignature, semanticAction}) => runTaskTool(
        const ToolCall(tool: 'back'),
        confirmedActionSignature: confirmedActionSignature,
        semanticAction: semanticAction,
      ),
      // NAV-MAP-04: action-space universal — desplazamiento por dirección.
      swipe: (direction) => runTaskTool(
        ToolCall(tool: 'scroll', args: {'direction': direction}),
        semanticAction: 'openConversation',
      ),
      resolveAppPackage: (appReference) async {
        final match = await ref
            .read(installedAppCatalogProvider)
            .findApp(appReference);
        return match is AppMatchResolved ? match.app.packageName : null;
      },
      currentSituationSource: ref.watch(currentSituationSourceProvider),
      // La navegación orientada a objetivos puede escalar percepción cuando
      // el árbol estructural no basta. La evidencia OCR/Vision nunca se toca
      // directamente: TaskOrchestrator debe re-ligarla a un único control
      // accesible actual antes de producir una acción.
      targetPerception: (concept, packageName) => ref
          .read(perceptionMuxProvider)
          .perceive(
            PerceptionRequest(
              targetConcept: concept,
              packageName: packageName,
              minimumConfidence: 0.72,
            ),
            budget: const PerceptionBudget(
              maxAccessibilityReads: 1,
              maxOcrCalls: 1,
              maxVisionCalls: 1,
              maxFullScreenVisionCalls: 1,
            ),
            policy: const ObservationPolicy(
              allowMemory: true,
              allowAccessibility: true,
              allowOcr: true,
              allowVision: true,
              allowFullScreenVision: true,
              minimumConfidence: 0.72,
            ),
          ),
      memorySource: () => ref.read(objectMemoryProvider),
      // AUT-MEM-01: memoria de transiciones verificadas (instancia única).
      memory: ref.watch(verifiedTransitionMemoryProvider),
      // T2.0 — resolución grounded de superficies UI desde el snapshot real
      // (Accessibility → ScreenGraph). Sin superficie → null (el paso reporta
      // needsMoreEvidence, no inventa selector).
      resolveInputSurface: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return const InputSurfaceResolver().resolve(g)?.selector;
      },
      resolveInputSurfaceFor: (kind) async {
        final g = await currentGraph();
        if (g == null) return null;
        final inputKind = switch (kind) {
          'message' => InputSurfaceKind.message,
          'search' => InputSurfaceKind.search,
          _ => InputSurfaceKind.any,
        };
        return const InputSurfaceResolver()
            .resolve(g, kind: inputKind)
            ?.selector;
      },
      resolveActionSurface: (kind) async {
        final g = await currentGraph();
        if (g == null) return null;
        final surface = const ActionSurfaceResolver().resolve(g, kind: kind);
        if (surface == null && kDebugMode) {
          final candidates = g.objects
              .where((object) {
                final evidence =
                    '${object.label} ${object.text} ${object.description} '
                            '${object.resourceId}'
                        .toLowerCase();
                return evidence.contains('search') ||
                    evidence.contains('buscar') ||
                    evidence.contains('busca');
              })
              .map(
                (object) =>
                    '${object.role.name}|click=${object.clickable}|'
                    'enabled=${object.enabled}|id=${object.resourceId}|'
                    'text=${object.text}|desc=${object.description}',
              );
          debugPrint(
            '[automation-surface] unresolved kind=$kind '
            'package=${g.package} truncated=${g.truncated} '
            'objects=${g.objects.length} candidates=${candidates.join(' || ')}',
          );
        }
        return surface?.selector;
      },
      // T2.9-select — resolución grounded de un resultado observado
      // (ordinal/texto) desde el ScreenGraph real, nunca coordenadas.
      resolveResult: (target) async {
        final g = await currentGraph();
        if (g == null) return null;
        return const SearchResultResolver().resolve(g, target);
      },
      // T2.9-verify — fingerprint de texto visible (PRE/POST) y conteo de
      // resultados, para verificar submit/selección observando el estado real.
      readVisibleText: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return g.objects
            .where((o) => o.visible && o.text.isNotEmpty)
            .map((o) => o.text)
            .join(' | ');
      },
      detectSearchResults: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return const SearchResultResolver().resolveResults(g).length;
      },
      commitGuard: CommitGuard(observe: currentGraph),
      journal: ref.watch(executionJournalProvider),
      // SKILL-01 — trazas verificadas → drafts de skills (best-effort: el
      // collector nunca interfiere con la ejecución de la tarea).
      onVerifiedStep: (entry) {
        try {
          ref.read(skillCollectorProvider).collectEntry(entry);
        } on Object catch (error) {
          debugPrint('[skills] recolección de draft falló: $error');
        }
      },
    ),
    // A15.2: descomposición template determinista + LLM validado.
    taskDecomposer: LlmTaskDecomposer(
      client: ref.read(runtimeEngineProvider.notifier).client,
      resolver: ref.watch(automationModelResolverProvider),
      ensureReady: (path) =>
          ref.read(runtimeEngineProvider.notifier).ensureReady(modelPath: path),
    ),
  );
});

/// Registro de reglas persistentes (T3.1): shared_prefs JSON. La carga es
/// asíncrona (arranque); el pipeline consulta `rules` en memoria.
final ruleRegistryProvider = Provider<RuleRegistry>((ref) {
  final registry = RuleRegistry(SharedPrefsRuleStore());
  return registry;
});

/// Puerta de idempotencia de eventos (WA-DEDUPE-03 / T3.6): memoria de
/// eventos vistos + ecos de envíos + cooldown por conversación. Persistente
/// (shared_prefs JSON); la carga es asíncrona (arranque) igual que las reglas.
final eventDedupeStoreProvider = Provider<EventDedupeStore>((ref) {
  final store = SqliteEventDedupeStore();
  return store;
});

/// RATE-01: límite duro de respuestas por conversación (ventana deslizante).
/// Persistente (shared_prefs JSON), misma carga asíncrona que el dedupe.
final contactRateLimiterProvider = Provider<ContactRateLimiter>((ref) {
  final limiter = SqliteContactRateLimiter();
  return limiter;
});

/// WA-PROD-02 — barrera global de hidratación: futuro único que espera la
/// carga completa de los stores críticos (reglas, dedupe, memoria) +
/// settings. RulePipeline la espera antes del primer evento/tick y el
/// runtime headless antes de drenar el inbox — la ventana de decisión
/// pre-hidratación queda cerrada para CUALQUIER consumidor del grafo.
/// (El rate limiter no entra: se auto-hidrata dentro de allowReply antes de
/// decidir — mismo patrón que su impl de prefs.)
final automationStoresHydratedProvider = Provider<Future<void>>((ref) async {
  await ref.read(settingsProvider.notifier).init();
  await Future.wait([
    ref.read(ruleRegistryProvider).load(),
    ref.read(eventDedupeStoreProvider).load(),
    ref.read(conversationMemoryStoreProvider).load(),
    ref.read(businessFactsNotifierProvider.notifier).ready,
    ref.read(toneProfileNotifierProvider.notifier).ready,
    ref.read(conversationStateNotifierProvider.notifier).ready,
    // PERSONA-STORAGE-04 — ownership hidratado antes de decidir.
    ref.read(conversationOwnershipStoreProvider).load(),
    // PERSONA-COMPOSE-08 — perfil del dueño + relaciones en cache antes de
    // que el writer arme bloques <DATOS DE LA PERSONA>.
    ref.read(personaContextProvider).load(),
  ]);
});

/// Helper canónico para construir el contexto de decisión factual del turno.
ConversationDecisionContext _buildConversationDecisionContext(
  Ref ref,
  NotificationObject notif,
) {
  final identity = resolveConversationIdentity(notif);
  final ownership = ref
      .read(conversationOwnershipStoreProvider)
      .ownershipFor(identity.key.id);
  final entry = ref.read(
    conversationStateNotifierProvider,
  )[identity.key.id];
  final hasActiveProduct =
      entry != null &&
      entry.product != null &&
      entry.topicStatus == 'active';
  final hasPendingQuestion =
      entry != null && entry.pendingQuestion.isNotEmpty;
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
  );
  final mode = ConversationAutonomyModeName.fromName(
    ref.read(settingsProvider).waAutonomyMode,
  );
  debugPrint(
    '[agent] rol=${routing.role.name} modo=${mode.name} '
    '${routing.reasons.join(' | ')}',
  );
  return ConversationDecisionContext(
    humanOwnsConversation: ownership?.humanOwns ?? false,
    identityConfidence: identity.confidence,
    autonomyMode: mode,
    agentRole: routing.role,
    userText: notif.text,
    senderName: notif.sender,
  );
}

/// Proveedor único del compositor conversacional canónico para toda la aplicación.
/// Orquesta FastPath, RuntimeNotificationDraftWriter, SafeConversationRepair y
/// ConversationDecisionEngine con la misma identidad, memoria y persona.
final conversationReplyComposerProvider =
    Provider<ConversationReplyComposer>((ref) {
  return RuntimeConversationReplyComposer(
    draftSource: ref.watch(notificationDraftSourceProvider),
    fastPath: PragmaticFastPath(
      memoryFor: (id) =>
          ref.read(conversationMemoryStoreProvider).memoryFor(id),
      contextEntryFor: (id) =>
          ref.read(conversationStateNotifierProvider)[id],
      ownerName: () => ref.read(personaContextProvider).ownerName,
      metricsSource: DeviceMetrics.fetch,
    ),
    decisionEngine: const ConversationDecisionEngine(),
    thermalStatus: () => LanguageAssistService().thermalStatus(),
    decisionContext: (notif) => _buildConversationDecisionContext(ref, notif),
  );
});

/// Pipeline WhatsApp-first (T3.3): notificación → dedupe → match → coordinator.
/// El dispatcher ejecuta el goal por el MISMO coordinator (nunca un motor aparte).
final rulePipelineProvider = Provider<RulePipeline>((ref) {
  return RulePipeline(
    registry: ref.watch(ruleRegistryProvider),
    engine: const RuleEngine(),
    dedupe: ref.watch(eventDedupeStoreProvider),
    memory: ref.watch(conversationMemoryStoreProvider),
    rateLimiter: ref.watch(contactRateLimiterProvider),
    readiness: ref.watch(automationStoresHydratedProvider),
    supersedeGuard: ref.watch(turnSupersedeGuardProvider),
    dispatcher: RuleDispatcher(
      (goal, {AutomationOptions? options}) => ref
          .read(automationCoordinatorProvider)
          .execute(goal, options: options),
      composer: ref.watch(conversationReplyComposerProvider),
      supersedeGuard: ref.watch(turnSupersedeGuardProvider),
      // WA-DELAY-01 — pausa de reply leída EN VIVO al despachar (closure,
      // no watch: el dispatcher es estable y el delay cambia por llamada).
      replyDelay: () =>
          Duration(seconds: ref.read(settingsProvider).waReplyDelaySeconds),
      pendingReplyStore: ref.watch(pendingReplyStoreProvider),
      decisionContext: (notif) => _buildConversationDecisionContext(ref, notif),
      // NOTIFY-01: RuleAction.notify materializa un aviso local real (canal
      // nano_rule_notices). Fallo honesto si el sistema lo rechaza.
      notifyLocal: (title, body) =>
          NanoRuntimeApi.instance.notifyRuleEvent(title: title, body: body),
      // WA-MEDIA-01: RuleAction.sendMedia abre WhatsApp con el archivo del
      // catálogo (Camino A, 1 tap del usuario).
      shareMedia: (path, contact, caption) => const WhatsAppMediaShare()
          .shareFile(path: path, contact: contact, caption: caption),
    ),
  );
});

/// WA-CONV-03 — versión por conversación (instancia única del engine): el
/// BurstTurnGate la incrementa por cada inbound, el RulePipeline también en
/// rutas sin gate y el RuleDispatcher captura/verifica antes del envío.
final turnSupersedeGuardProvider = Provider<TurnSupersedeGuard>((ref) {
  final guard = TurnSupersedeGuard();
  ref.onDispose(guard.invalidateAll);
  return guard;
});

/// PERSONA-HANDOFF-03 + PERSONA-STORAGE-04 — ownership por conversación
/// durable: cache en memoria + sección "ownership" de SQLite (hidratada por
/// la barrera global antes del primer evento del pipeline).
final conversationOwnershipStoreProvider =
    Provider<SqliteConversationOwnershipStore>((ref) {
      return SqliteConversationOwnershipStore();
    });

/// WA-TURN-01 — puerta de ráfagas por conversación (una por engine): agrupa
/// mensajes de la misma conversación en un único turno y serializa los
/// turnos por chat. La usa el router de eventos vivos Y el drenado headless.
final burstTurnGateProvider = Provider<BurstTurnGate>((ref) {
  final gate = BurstTurnGate(
    // WA-CONV-03: cada mensaje REAL (incluido el que llega mientras un turno
    // corre) incrementa la versión → supersede del draft en curso.
    onInbound: (conversationId) =>
        ref.read(turnSupersedeGuardProvider).bump(conversationId),
    // WA-STATE-01 + Ronda 3: al terminar un turno agregado, registrar el
    // turno completo: producto consultado, pregunta pendiente del reply y
    // cierre de tema (recordTurn filtra determinista lo que no aplica).
    onTurnComplete: (conversationId, aggregated, {dispatchedText = ''}) async {
      if (conversationId.isEmpty) return;
      final text = aggregated.messageText.isNotEmpty
          ? aggregated.messageText
          : aggregated.text;
      await ref
          .read(conversationStateNotifierProvider.notifier)
          .recordTurn(
            conversationId: conversationId,
            userText: text,
            nanoReply: dispatchedText,
            facts: ref.read(businessFactsNotifierProvider),
            // CONV-STATE-03 — corrección/rechazo invalida el recuerdo de
            // producto y el tema activo (misma señal determinista del router).
            correction: isCorrectionMessage(text),
          );
    },
  );
  ref.onDispose(gate.dispose);
  return gate;
});

/// Router de eventos en vivo de notificación (T3.2): EventChannel nativo →
/// BurstTurnGate (agregación por conversación) → RulePipeline. Arranca al
/// leerse por primera vez (escucha de por vida).
final notificationEventRouterProvider = Provider<NotificationEventRouter>((
  ref,
) {
  final router = NotificationEventRouter(
    pipeline: ref.watch(rulePipelineProvider),
    gate: ref.watch(burstTurnGateProvider),
  )..start();
  ref.onDispose(router.stop);
  return router;
});

/// TRIG-01 — ticker de reloj en-app: productor real de TickEvent para reglas
/// de hora (TimeTrigger). Arranca al leerse (dashboard lo mantiene vivo igual
/// que el router) y alimenta el MISMO pipeline que las notificaciones.
final timeTickSchedulerProvider = Provider<TimeTickScheduler>((ref) {
  final scheduler = TimeTickScheduler(
    onMinute: (event) => ref.read(rulePipelineProvider).onTick(event),
  )..start();
  ref.onDispose(scheduler.stop);
  return scheduler;
});

/// WA-DRAFT-INBOX-01 — almacén durable de borradores para aprobación (Modo Sugerencias).
final pendingReplyStoreProvider = Provider<PendingReplyStore>((ref) {
  return PendingReplyStore(dbClient: AutomationDbStoreClient.instance);
});

final pendingRepliesProvider =
    FutureProvider.autoDispose<List<PendingReply>>((ref) async {
  final store = ref.watch(pendingReplyStoreProvider);
  return store.allPending();
});
