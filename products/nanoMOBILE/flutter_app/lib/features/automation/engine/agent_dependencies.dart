import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/linux/linux_distribution_registry.dart';
import '../../../core/services/nano_runtime_api.dart';
import '../../../core/services/runtime_engine.dart';
import '../../../core/services/rootfs_manager.dart';
import '../../../core/services/shell_executor.dart';
import '../../../core/services/shell_executor_linux_backend.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../domain/automation_policy.dart';
import 'business/business_facts_providers.dart';
import 'messaging/conversation_memory.dart'
    show ConversationMemoryStore, SqliteConversationMemoryStore;
import 'model/automation_model_resolver.dart';
import 'model/draft_writer.dart';
import 'platform/linux_tool_adapter.dart';
import 'execution/action_path_router.dart';
import 'execution/action_verifier.dart';
import 'execution/platform_verification_router.dart';
import 'execution/agent_executor.dart';
import 'execution/agent_tool_dispatcher.dart';
import 'memory/experience_cache.dart';
import 'memory/object_memory.dart';
import 'memory/verified_transition_memory.dart';
import 'execution/goal_verifier.dart';
import 'execution/nano_flow.dart';
import 'execution/stability_gate.dart';
import 'execution/tool_registry.dart';
import 'orchestration/execution_journal.dart';
import 'platform/nano_system_api.dart';
import 'system/app_launch_resolver.dart';
import 'system/capability_probes.dart';
import 'system/installed_app_catalog.dart';
import 'system/system_graph.dart';
import 'system/system_intent_launcher.dart';
import 'system/system_inventory.dart';
import 'perception/mux/accessibility_perception_source.dart';
import 'perception/mux/object_memory_perception_source.dart';
import 'perception/mux/ocr_perception_source.dart';
import 'perception/mux/mlkit_vision_backend.dart';
import 'perception/mux/vision_perception_source.dart';
import 'perception/mux/perception_source.dart';
import 'perception/mux/visual_resource_policy.dart';
import 'perception/nano_snapshot.dart';
import 'perception/perception_mux.dart';
import 'perception/current_situation.dart';
import 'perception/semantic/screen_graph.dart';
import 'perception/surface_classifier.dart';
import 'platform/nano_ocr_api.dart';
import 'governance/action_governance_pipeline.dart';
import 'privilege/shizuku_availability.dart';
import 'privilege/shizuku_native_provider.dart';
import 'governance/intent_firewall.dart';
import 'governance/pre_action_critic.dart';
import 'governance/privilege_broker.dart';
import 'planning/candidate_first_planner.dart';
import 'planning/koog_shadow.dart' show KoogShadowObserver;
import 'planning/koog_supervisor.dart' show KoogSupervisor, LlmKoogSupervisor;
import 'planning/candidates/candidate_generator.dart';
import 'planning/candidates/candidate_providers.dart';
import 'model/automation_model.dart' show AutomationModelRole;
import 'notifications/notification_draft_writer.dart';
import 'planning/candidates/notification_candidate_provider.dart';
import 'planning/candidates/notification_data_candidate_provider.dart';
import 'planning/candidates/candidate_ranker.dart';
import 'planning/candidates/candidate_selection_engine.dart';
import 'planning/candidates/candidate_selector.dart';
import 'planning/candidates/candidate_tool_call_adapter.dart';
import 'planning/candidates/koog_candidate_selector.dart';
import 'planning/candidates/screen_graph_candidate_provider.dart';
import 'planning/deterministic_catalog.dart';
import 'skills/approved_skill_candidate_provider.dart';
import 'skills/nano_skill.dart';
import 'skills/nano_skills.dart';
import 'skills/skill_extractor.dart';
import 'skills/skill_store.dart';
import 'system/system_intent_catalog.dart';

/// Composition root del agente (DIP/SRP): TODAS las dependencias del agente
/// se construyen UNA vez aquí con sus implementaciones reales y se inyectan a
/// los consumidores. Regla: ningún consumidor instancia `new NanoAgentExecutor`
/// / `new ActionVerifier` / `new AgentToolDispatcher` — los recibe por
/// constructor o por provider.
///
/// El cableado es el del runtime real (canal `com.nanoai/agent`); los tests
/// inyectan fakes en su lugar (ver chat_provider `toolDispatcher:`).

/// Ejecutor real sobre el canal de accesibilidad.
final agentExecutorProvider = Provider<AgentExecutor>((ref) {
  return NanoAgentExecutor(api: NanoRuntimeApi.instance);
});

/// Verificador de postcondiciones que comparte el snapshot del executor.
/// A14.5: incorpora el lector de estado de plataforma (app en primer plano,
/// archivos Linux) para verificar acciones no-UI de forma factual.
final agentVerifierProvider = Provider<AgentVerifier>((ref) {
  final executor = ref.watch(agentExecutorProvider);
  return ActionVerifier(
    snapshotFn: executor.snapshot,
    platformReader: PlatformVerificationRouter(
      snapshotFn: executor.snapshot,
      systemStateSource: () => NanoRuntimeApi.instance.systemState(),
    ),
  );
});

/// Política de gobernanza con el registro canónico de tools.
final policyEngineProvider = Provider<PolicyEngine>((ref) {
  return PolicyEngine(
    registry: ToolRegistry.builtin,
    confirmationPolicy: (toolName) => AutomationPolicy(
      ref.read(settingsProvider).agentAutomationMode,
    ).requiresConfirmation(toolName),
  );
});

/// T1.2: adaptador Linux del agente sobre el backend CORE compartido con el
/// Terminal ([ShellExecutorLinuxBackend] → [ShellExecutor] → Nanoshell FFI).
/// Automation NO pasa por CommandExecutor ni por PTY para ejecución no
/// interactiva. Comparte el mismo [RootfsManager.instance] (lifecycle canónico).
final linuxToolAdapterProvider = Provider<LinuxToolAdapter>((ref) {
  return LinuxToolAdapter(
    backend: ShellExecutorLinuxBackend(
      ShellExecutor(rootfs: RootfsManager.instance),
    ),
  );
});

/// Journal durable único para todas las fronteras de commit del módulo.
/// Compartir la instancia evita que dispatcher y TaskOrchestrator mantengan
/// estados transaccionales separados para la misma acción física.
final executionJournalProvider = Provider<ExecutionJournal>((ref) {
  return SharedPreferencesExecutionJournal();
});

/// Memoria aislada por conversación (WA-MEM-08): historial factual bounded por
/// ConversationKey con honestidad de outbound (verified/dispatched/unknown).
/// Persistente (shared_prefs JSON); la carga es asíncrona (arranque).
final conversationMemoryStoreProvider = Provider<ConversationMemoryStore>((
  ref,
) {
  final store = SqliteConversationMemoryStore();
  store.load();
  return store;
});

/// Fuente factual compartida de la situación actual. Cada invocación captura
/// un snapshot fresco y pasa por el único SurfaceClassifier del módulo.
final currentSituationSourceProvider = Provider<CurrentSituationSource>((ref) {
  final executor = ref.watch(agentExecutorProvider);
  const classifier = SurfaceClassifier();
  return () async {
    final snapshot = await executor.snapshot();
    if (snapshot == null || snapshot.isEmpty) return null;
    return classifier.classify(
      ScreenGraph.fromSnapshot(snapshot),
      observedAt: snapshot.capturedAt,
    );
  };
});

/// Dispatcher con TODAS sus dependencias inyectadas (sin defaults internos
/// en producción). El chat lo recibe vía `chatProvider`.
final agentDispatcherProvider = Provider<AgentToolDispatcher>((ref) {
  final api = NanoRuntimeApi.instance;
  final executor = ref.watch(agentExecutorProvider);
  return AgentToolDispatcher(
    executor: executor,
    registry: ToolRegistry.builtin,
    policy: ref.watch(policyEngineProvider),
    verifier: ref.watch(agentVerifierProvider),
    linuxAdapter: ref.watch(linuxToolAdapterProvider),
    router: ref.watch(actionPathRouterProvider),
    launchPackage: api.agentLaunchPackage,
    globalAction: api.agentGlobalAction,
    swipe: api.agentSwipe,
    longPress: api.agentLongPressAt,
    executionJournal: ref.watch(executionJournalProvider),
    currentSituationSource: ref.watch(currentSituationSourceProvider),
    voiceOutputEnabled: () => ref.read(settingsProvider).voiceEnabled,
    systemIntentLauncher: ref.watch(systemIntentLauncherProvider),
    // A14.5: lector de estado de plataforma para verificar postcondiciones
    // no-UI (archivo Linux, app fuera de foco) tras ejecutar.
    platformStateReader: PlatformVerificationRouter(
      snapshotFn: ref.watch(agentExecutorProvider).snapshot,
      linuxAdapter: ref.watch(linuxToolAdapterProvider),
      systemStateSource: () => NanoRuntimeApi.instance.systemState(),
    ),
    // A14.5: fuentes REALES del informe ejecutivo (@capacidades) y apertura de
    // pantallas de permiso (@conceder_<x>). Lee el SystemGraph y el estado de
    // permisos/Shizuku del dispositivo — nada simulado.
    systemGraphSource: () => ref.read(systemGraphProvider.future),
    devicePermissionsSource: () =>
        NanoRuntimeApi.instance.devicePermissionStatus(),
    shizukuStatusSource: () => NanoRuntimeApi.instance.queryShizukuStatus(),
    openPermissionSource: (kind) {
      switch (kind) {
        case 'accessibility':
          return NanoRuntimeApi.instance.openAccessibilitySettings();
        case 'notificaciones':
          return NanoRuntimeApi.instance.openNotificationAccessSettings();
        case 'archivos':
          return NanoRuntimeApi.instance.openAllFilesAccessSettings();
        case 'runtime':
          return NanoRuntimeApi.instance.requestRuntimePermissions();
        default:
          return Future.value(false);
      }
    },
  );
});

/// Estabilidad del árbol semántico (C4): espera asentamiento bounded.
final stabilityGateProvider = Provider<StabilityGate>((ref) {
  return StabilityGate(snapshotFn: ref.watch(agentExecutorProvider).snapshot);
});

/// Router de ruta de ejecución (C6): comparte el estado real de Linux.
final actionPathRouterProvider = Provider<ActionPathRouter>((ref) {
  return ActionPathRouter(
    // Linux disponible cuando hay distribuciones registradas en el
    // subsistema (termux/kali/ubuntu instalados).
    linuxAvailable: () =>
        LinuxDistributionRegistry.instance.getAllDistributions().isNotEmpty,
  );
});

/// Memoria de ejecuciones verificadas (C7): única por app, en memoria.
final experienceCacheProvider = Provider<ExperienceCache>((ref) {
  return ExperienceCache();
});

/// AUT-MEM-01 — memoria de transiciones verificadas (DroidBot/AppAgent):
/// registra solo transiciones confirmadas por reobservación y sugiere el
/// orden de recuperación. En memoria por sesión; el navigator siempre
/// reobserva y verifica (MEMORY MAY PROPOSE; CURRENT SCREEN MUST VERIFY).
final verifiedTransitionMemoryProvider = Provider<VerifiedTransitionMemory>(
  (ref) => VerifiedTransitionMemory(),
);

/// Verificador del objetivo final (C3), sobre el MISMO executor del dispatcher.
/// A14.5.4: incorpora el lector de estado semántico (media/Bluetooth/WiFi/texto).
final goalVerifierProvider = Provider<GoalVerifier>((ref) {
  final executor = ref.watch(agentExecutorProvider);
  return GoalVerifier(
    executor: executor,
    stateReader: PlatformVerificationRouter(
      snapshotFn: executor.snapshot,
      linuxAdapter: ref.watch(linuxToolAdapterProvider),
      systemStateSource: () => NanoRuntimeApi.instance.systemState(),
    ),
  );
});

/// Ejecutor de flujos deterministas (C8): flujo verificado → ejecución sin
/// LLM, con la misma gobernanza que el plan del LLM.
final nanoFlowExecutorProvider = Provider<NanoFlowExecutor>((ref) {
  return NanoFlowExecutor(
    dispatcher: ref.watch(agentDispatcherProvider),
    goalVerifier: ref.watch(goalVerifierProvider),
  );
});

/// Inventario factual del sistema (A2): frontera MethodChannel → interface.
final systemInventoryProvider = Provider<SystemInventory>((ref) {
  return MethodChannelSystemInventory();
});

/// Catálogo de apps instaladas/launchable (A2): cachea + resuelve.
final installedAppCatalogProvider = Provider<InstalledAppCatalog>((ref) {
  return InstalledAppCatalog(ref.watch(systemInventoryProvider));
});

/// Resolvedor determinista de "abre <app>" grounded.
final appLaunchResolverProvider = Provider<AppLaunchResolver>((ref) {
  return AppLaunchResolver(ref.watch(installedAppCatalogProvider));
});

/// Navegación de sistema allowlisted (A3).
final systemIntentLauncherProvider = Provider<SystemIntentLauncher>((ref) {
  return MethodChannelSystemIntentLauncher();
});

/// Modelo factual del dispositivo (A3). Los probes leen estado real:
/// accessibility/notification vía devicePermissionStatus, Linux vía el registro
/// de distribuciones, Shizuku vía el canal nativo pasivo (A14.3).
/// Añadir ADB/root luego = añadir un probe.
final systemGraphBuilderProvider = Provider<SystemGraphBuilder>((ref) {
  return SystemGraphBuilder(
    inventory: ref.watch(systemInventoryProvider),
    catalog: ref.watch(installedAppCatalogProvider),
    probes: [
      const StaticSystemCapabilityProbe(),
      AccessibilityCapabilityProbe(() async {
        final s = await NanoRuntimeApi.instance.devicePermissionStatus();
        return s['accessibility'] == true;
      }),
      NotificationCapabilityProbe(() async {
        final s = await NanoRuntimeApi.instance.devicePermissionStatus();
        return s['notificationAccess'] == true;
      }),
      LinuxCapabilityProbe(
        () =>
            LinuxDistributionRegistry.instance.getAllDistributions().isNotEmpty,
      ),
      // A14.3: estado FACTUAL de Shizuku (binder + autorización) vía el canal
      // nativo pasivo. Solo disponibilidad — la ejecución es A14.4 tipada.
      ShizukuCapabilityProbe(ref.watch(shizukuAvailabilityProvider)),
      const SystemIntentCapabilityProbe(),
    ],
  );
});

/// A14.3 — proveedor de disponibilidad FACTUAL de Shizuku. Lee el estado real
/// del dispositivo (instalación + binder + autorización) sin ejecutar nada.
final shizukuAvailabilityProvider = Provider<ShizukuAvailabilityProvider>((
  ref,
) {
  return MethodChannelShizukuAvailabilityProvider();
});

/// Adapta el AgentExecutor (ya provee snapshot()) al ScreenObserver (DIP).
class _ExecutorScreenObserver implements ScreenObserver {
  _ExecutorScreenObserver(this._executor);
  final AgentExecutor _executor;

  @override
  Future<NanoSnapshot?> snapshot() => _executor.snapshot();
}

/// Contenedor mutable de la ÚNICA instancia productiva de ObjectMemory V2.
/// El NanoObjectMemory es inmutable; el notifier mantiene el estado actual
/// compartido por PerceptionMux y AutomationCoordinator (sin split-brain).
class ObjectMemoryNotifier extends StateNotifier<NanoObjectMemory> {
  ObjectMemoryNotifier() : super(const NanoObjectMemory());

  void replace(NanoObjectMemory memory) => state = memory;
}

final objectMemoryProvider =
    StateNotifierProvider<ObjectMemoryNotifier, NanoObjectMemory>((ref) {
      return ObjectMemoryNotifier();
    });

/// Percepción orquestada (A8+A9): memoria → accesibilidad → OCR fallback.
final perceptionMuxProvider = Provider<PerceptionMux>((ref) {
  final executor = ref.watch(agentExecutorProvider);
  return PerceptionMux(
    memorySource: ObjectMemoryPerceptionSource(
      () => ref.read(objectMemoryProvider),
    ),
    accessibilitySource: AccessibilityPerceptionSource(
      _ExecutorScreenObserver(executor),
    ),
    ocrSource: OcrPerceptionSource(
      const AccessibilityScreenImageProvider(),
      MlKitOcrBackend(),
    ),
    // A16: visión on-device (ML Kit Image Labeling) como ÚLTIMO escalado.
    visionSource: VisionPerceptionSource(
      const AccessibilityScreenImageProvider(),
      const MlKitVisionBackend(),
    ),
    // AUT-VIS-03: política de recursos del modelo visual. La fuente de RAM
    // real se conecta aquí cuando el canal exponga el campo; sin fuente, la
    // política permite (degradación = comportamiento actual, sin romper).
    resourcePolicy: MobileVisualResourcePolicy(
      minAvailableRamMb: 512,
      availableRamMb: null,
    ),
  );
});

/// SystemGraph REAL (A15.7): construido async (device profile + apps + probes de
/// capability). Cacheado por el FutureProvider. Alimenta Candidate-First y el
/// governance (availability factual).
final systemGraphProvider = FutureProvider<SystemGraph>((ref) {
  return ref.watch(systemGraphBuilderProvider).build();
});

/// Resolución Modelo ↔ Automation (T4.2): un solo runtime, modo + modelo actual.
/// El modo `deterministicOnly` o un modelo ausente → llmAllowed=false.
final automationModelResolverProvider = Provider<AutomationModelResolver>((
  ref,
) {
  return AutomationModelResolver(
    mode: () => ref.read(settingsProvider).automationModelMode,
    chatModelPath: () => ref.read(chatProvider).activeModelPath,
    automationModelPath: () => ref.read(settingsProvider).automationModelPath,
  );
});

/// Koog selector (A15.8): resuelve ambigüedad Candidate-First con candidateId
/// (mismo runtime local que el planner LLM, no un segundo modelo). Gateado por
/// el resolver de modelo: deterministicOnly/sin modelo → 0 LLM.
final koogCandidateSelectorProvider = Provider<CandidateSelector>((ref) {
  return ModelGatedCandidateSelector(
    inner: KoogCandidateSelector(
      ref.read(runtimeEngineProvider.notifier).client,
    ),
    resolver: ref.watch(automationModelResolverProvider),
  );
});

/// Supervisor Koog (WA-KOOG-10): decisión tipada del siguiente paso del ciclo
/// sobre candidatos EXISTENTES (mismo runtime local, no un segundo modelo).
/// Solo PROPONE: jamás ejecuta, autoriza ni verifica.
final koogSupervisorProvider = Provider<KoogSupervisor>((ref) {
  return LlmKoogSupervisor(ref.read(runtimeEngineProvider.notifier).client);
});

/// Extractor de skills (SKILL-01): trazas VERIFICADAS del journal → drafts.
/// Puro y determinista: deriva condiciones de la política semántica canónica.
final skillExtractorProvider = Provider<SkillExtractor>((ref) {
  return const PolicySkillExtractor();
});

/// Store de skills (SKILL-01): drafts + aprobaciones explícitas del usuario.
/// Persistente (shared_preferences JSON); la carga es asíncrona (arranque).
final skillStoreProvider = Provider<SkillStore>((ref) {
  final store = SharedPrefsSkillStore();
  store.load();
  return store;
});

/// Recolector de skills (SKILL-01): puente journal → drafts. Best-effort.
final skillCollectorProvider = Provider<SkillCollector>((ref) {
  return SkillCollector(
    extractor: ref.watch(skillExtractorProvider),
    store: ref.watch(skillStoreProvider),
  );
});

/// Observador shadow del supervisor (WA-KOOG-10). ROLLOUT: deshabilitado por
/// defecto (costo cero: no llama al LLM). Activación explícita cuando
/// WA-PHYS-11 valide el pipeline: shadow → medir desacuerdos → autoridad de
/// selección SOLO con la frontera de candidatos demostrada.
final koogShadowObserverProvider = Provider<KoogShadowObserver>((ref) {
  return KoogShadowObserver(
    supervisor: ref.watch(koogSupervisorProvider),
    onDisagreement: (d) => debugPrint(
      '[koog-shadow] desacuerdo | goal="${d.contextGoal}" | '
      'autoritativo=${d.authoritative.name}'
      '${d.authoritativeCandidateId != null ? ' (${d.authoritativeCandidateId})' : ''}'
      ' | koog=${d.koogDecision.runtimeType}',
    ),
    enabled: false, // activación explícita tras validación física
  );
});

/// Redacción de borradores (T4.3): MISMO runtime, role=draftWriter.
final automationDraftWriterProvider = Provider<AutomationDraftWriter>((ref) {
  final engine = ref.read(runtimeEngineProvider.notifier);
  return RuntimeAutomationDraftWriter(
    resolver: ref.watch(automationModelResolverProvider),
    client: engine.client,
    ensureReady: (p) => engine.ensureReady(modelPath: p),
  );
});

/// Redacción contextual de respuestas a notificación (WA-AGENT-09): el motor
/// local lee el contenido REAL y el historial factual de la conversación y
/// redacta la respuesta. Gateada por el resolver de modelo (sin LLM permitido
/// o sin motor → null, jamás texto genérico). Compartida por el candidato de
/// notificación (respuestas del chat) y las reglas reply dinámicas.
final notificationDraftSourceProvider = Provider<NotificationDraftSource>((
  ref,
) {
  final engine = ref.read(runtimeEngineProvider.notifier);
  final resolver = ref.watch(automationModelResolverProvider);
  return RuntimeNotificationDraftWriter(
    client: engine.client,
    llmAllowed: () =>
        resolver.resolveFor(AutomationModelRole.draftWriter).llmAllowed,
    ensureReady: (p) => engine.ensureReady(modelPath: p),
    modelPath: () =>
        resolver.resolveFor(AutomationModelRole.draftWriter).modelPath,
    // WA-PERSONA-01 — estilo del dueño leído EN VIVO al redactar.
    styleEnabled: () => ref.read(settingsProvider).waStyleEnabled,
    styleText: () => ref.read(settingsProvider).waStyleText,
    // WA-BUSINESS-01 — hechos del negocio leídos EN VIVO al redactar.
    businessBlock: () =>
        ref.read(businessFactsNotifierProvider).formatPromptBlock(),
    // WA-MEM-08: contexto factual de la conversación.
    memory: ref.watch(conversationMemoryStoreProvider),
  ).call;
});

/// Planificador Candidate-First de producción (A13.5/A15.7): generator →
/// selection → governance → adapter, con SystemGraph real cargado lazy.
final candidateFirstPlannerProvider = Provider<CandidateFirstPlanner>((ref) {
  // Capturar dependencias estables durante el build (no usar ref dentro del
  // closure generatorBuilder, que corre en runtime dentro de plan()).
  final experienceCache = ref.watch(experienceCacheProvider);
  final installedCatalog = ref.watch(installedAppCatalogProvider);
  final executor = ref.watch(agentExecutorProvider);
  final notificationDraft = ref.watch(notificationDraftSourceProvider);
  final skillStore = ref.watch(skillStoreProvider);

  return CandidateFirstPlanner(
    generatorBuilder: (graph) {
      // SKILL-CONS-01: skills aprobadas por el usuario → NanoSkill concreto.
      // Solo acciones con skill real; el resto cae a null (sin bridges
      // inventados). graph llega del builder porque SystemNavigationSkill lo
      // necesita.
      NanoSkill? resolveSkill(String semanticAction) {
        switch (semanticAction) {
          case 'openApp':
          case 'open_app':
            return OpenAppSkill(installedCatalog);
          case 'readNotification':
          case 'notifications':
            return ReadNotificationsSkill(defaultDeterministicCatalog);
          case 'open_system':
            return SystemNavigationSkill(
              defaultDeterministicCatalog,
              graph,
              SystemIntentCatalog.builtin,
            );
        }
        return null;
      }

      return CandidateActionGenerator([
        ApprovedSkillCandidateProvider(skillStore, resolveSkill),
        NanoFlowCandidateProvider(experienceCache),
        SystemIntentCandidateProvider(
          defaultDeterministicCatalog,
          graph,
          SystemIntentCatalog.builtin,
        ),
        InstalledAppCandidateProvider(installedCatalog),
        DeterministicCandidateProvider(defaultDeterministicCatalog),
        ScreenGraphCandidateProvider(_ExecutorScreenObserver(executor)),
        // A14.6: notificaciones contestables como capacidad genérica (RemoteInput).
        // A14.7: sin texto del usuario, el draft contextual LEE y ENTIENDE el
        // contenido real de la notificación con el runtime local (gateado por
        // el resolver de modelo; sin modelo → sin borrador → abrir la app).
        NotificationCandidateProvider(
          () => NanoRuntimeApi.instance.listActiveNotifications(),
          draftSource: notificationDraft,
        ),
        // A14.9: extracción de datos observados (URL) → Linux write (cross-app).
        NotificationDataCandidateProvider(
          () => NanoRuntimeApi.instance.listActiveNotifications(),
        ),
      ]);
    },
    selection: CandidateSelectionEngine(
      ranker: CandidateRanker(),
      koogSelector: ref.watch(koogCandidateSelectorProvider),
    ),
    governance: const ActionGovernancePipeline(
      firewall: IntentFirewall(),
      critic: PreActionCritic(),
      broker: PrivilegeBroker(),
    ),
    adapter: CandidateToolCallAdapter(),
    getGraph: () => ref.read(systemGraphProvider.future),
    shizukuSource: () => ref.read(shizukuAvailabilityProvider).status(),
    koogShadow: ref.watch(koogShadowObserverProvider),
  );
});
