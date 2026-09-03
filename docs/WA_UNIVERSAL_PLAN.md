# NANO — Inyección Universal de WhatsApp (Plan de Sprints)

Fecha: 2026-09-02. Estado base: programa NANO-WA-COMPLETE cerrado (GATE-00 → WA-PHYS-11 → UNI-01) en `master` (b9b37a1), certificación física en Oppo CPH2557 completada con evidencia real (dumpsys + shared_prefs + confirmación del usuario).

Este documento define CÓMO absorber los patrones fuertes de Mobilerun/DroidRun, OpenDroid, MobileClaw, Mobile-Agent v3.5, ToolCUA, Gemini y AppFunctions **sin dañar la lógica real, sin duplicar y sin redundancia**. No es un documento teórico: cada sprint lista archivos exactos, contratos y criterios de cierre.

---

## 0. Invariantes absolutas (no negociables en NINGÚN sprint)

Estas piezas son el sistema nervioso. Ningún sprint las toca, debilita, envuelve en bypass ni duplica:

| Invariante | Archivo(s) |
|---|---|
| `AutomationCoordinator` — único dueño del ciclo | `lib/features/automation/application/automation_coordinator.dart` |
| `PolicyEngine` + `ToolRegistry` — única puerta de ejecución | `engine/execution/` |
| `ExecutionJournal` — exact-once, estados tipados | `engine/orchestration/execution_journal.dart` |
| `CommitGuard` — evidencia pre/post del único tap | `engine/orchestration/commit_guard.dart` |
| `outcomeUnknown` — terminal, NUNCA reintento ciego | commit_guard + task_orchestrator |
| `Candidate-First` — determinista primero, Koog solo en ambigüedad | `engine/planning/candidate_first_planner.dart` |
| `PerceptionMux` — estructural primero, visual segundo | `engine/perception/` |
| Autoridad única de ejecución: Koog/LLM PROPONE; Nano autoriza/ejecuta/verifica | todo el engine |

Regla de diseño transversal: **los sprints añaden observación, selección y presentación. No añaden rutas de ejecución paralelas.** Un efecto externo sigue teniendo exactamente UNA vía: Policy → Journal → CommitGuard → ejecutar una vez → reflejar.

---

## 1. Gap analysis (qué existe, qué falta)

### 1.1 Ya existe y NO se toca (las ideas ya fueron absorbidas)

| Idea del documento | Realidad Nano | Evidencia |
|---|---|---|
| Portal (árbol + estado + gestos + screenshot) | `AgentAccessibilityService.kt` + `ScreenGraph` + `NanoRuntimeApi` | kotlin/services/ |
| Auto-reply OpenDroid (listener + RemoteInput + cooldown) | `NotificationAutomationService` + `NotificationExecutor` + `ReplyCapabilityRef` | certificado WA-PHYS-11 |
| Bounceback detection | `DedupeVerdict.bounceback` | `event_dedupe_store.dart:46` |
| Self-reply suppression | eco del propio reply → `ignored` | evidencia física en Oppo (grupo) |
| Cooldown per-conversation | `DedupeVerdict.cooldown` + `cooldownMs` | certificado WA-PHYS-11 |
| Manager → una acción → reflejar | `CandidateFirstPlanner` + `CommitGuard.verifyAfterDispatch` | orchestrator |
| Replan / re-observación | `TaskOrchestrator` steps + `task_plan.dart` | grep replan |
| Assistant base | `NanoVoiceInteractionService` + `BIND_VOICE_INTERACTION` | manifest + kotlin/voice/ |
| OutgoingLedger | `ConversationMemoryStore` registra `outboundDispatched` | conversation_memory.dart |
| Grounding factual + exact-once + verificación | toda la cadena WA | master b9b37a1 |

### 1.2 Falta (gap real) — en este orden de prioridad

| # | Sprint | Qué falta | Inspiración |
|---|---|---|---|
| 1 | CAP-ROUTER-01 | Router semántico capability → mejor vía de ejecución (hoy la vía se elige implícitamente por flujo) | ToolCUA |
| 2 | RATE-01 | Rate limit duro per-contacto (N replies/ventana) sobre el cooldown existente | OpenDroid |
| 3 | EDGE-01 | Overlay accesibilidad contextual (búho encima de WhatsApp/otras apps) | Gemini + Portal (reimplementación propia, Portal es AGPL) |
| 4 | EDGE-02 | `SystemContextProvider`: fusión Assistant + Notifications + ScreenGraph + DeviceState | Portal |
| 5 | EDGE-03 | `ContextPanelRegistry` con paneles genéricos/mensajería/navegador/sistema | OCP |
| 6 | WA-MIRROR-01 | Conversation Mirror (historial + búsqueda + resumen desde el overlay) | ventaja sobre Gemini |
| 7 | SKILL-01 | SkillExtractor: trazas verificadas → skills semánticas (pre/postconditions) | MobileClaw |
| 8 | APPFN-01 | AppFunctions fast path oportunista (Android 16+) | Android AppFunctions |
| 9 | ROLE-01 | Solicitar ROLE_ASSISTANT cuando el usuario lo active | Gemini UX |

---

## 2. Sprint CAP-ROUTER-01 — CapabilityResolver (ToolCUA)

**Objetivo:** pieza pura que decide QUÉ vía ejecuta una capacidad semántica. No ejecuta nada: devuelve una ruta. Los ejecutores existentes (`NotificationReplyTransport`, `TaskOrchestrator`) siguen siendo los únicos ejecutores.

**Archivos nuevos (todos en `lib/features/automation/engine/capabilities/`):**

```
capabilities/
├── capability_intent.dart      // sealed: ConversationCapability.reply/read/summarize/search…
├── execution_path.dart         // enum: remoteInput, accessibilityGui, ocr, vision, appFunction, none
├── capability_path_policy.dart // política de ranking (const, auditable)
└── capability_resolver.dart    // router: intento + contexto observado → ExecutionPath
```

**Contratos:**

```dart
// capability_intent.dart
sealed class CapabilityIntent {
  const CapabilityIntent();
}
final class ReplyIntent extends CapabilityIntent {
  const ReplyIntent({required this.conversationKey, required this.draftText});
  final ConversationKey conversationKey;
  final String draftText;
}
final class ReadConversationIntent extends CapabilityIntent {
  const ReadConversationIntent(this.conversationKey);
  final ConversationKey conversationKey;
}
// summarizeIntent, searchIntent, openConversationIntent…

// execution_path.dart
enum ExecutionPath { appFunction, remoteInput, accessibilityGui, ocr, vision, none }

// capability_resolver.dart
final class ResolvedCapabilityRoute {
  const ResolvedCapabilityRoute({
    required this.path,
    required this.reason,
    required this.evidence,
  });
  final ExecutionPath path;
  final String reason;
  final CapabilityEvidence evidence;
}

abstract interface class CapabilityResolver {
  /// NUNCA ejecuta. NUNCA devuelve una ruta sin evidencia que la justifique.
  ResolvedCapabilityRoute resolve(CapabilityIntent intent, SystemObservation obs);
}
```

**Reglas duras:**
- `ReplyIntent` con `ReplyCapabilityRef.isUsable` revalidada → `remoteInput` SIEMPRE (evidencia física: es la vía exacta y sin gestos).
- Sin RemoteInput → `accessibilityGui` SOLO si el ScreenGraph muestra conversación exacta (`ConversationKey` coincide) y el perfil de superficie resuelve composer+send.
- `ocr`/`vision` solo como ruta de observación suplementaria, nunca ruta principal de ejecución.
- `appFunction` reservado para APPFN-01; hasta entonces `none` con razón honesta.
- La política de ranking vive en un `const` con comentario de por qué (números no mágicos).

**Cierre:** resolver devuelve rutas correctas para (a) notificación con RemoteInput, (b) conversación abierta sin RemoteInput, (c) contexto sin evidencia → `none`. Compilar sin errores. Ningún executor tocado.

---

## 3. Sprint RATE-01 — Rate limit per-contacto

**Objetivo:** capa dura encima del cooldown: por `ConversationKey`, máximo N respuestas por ventana de tiempo. El cooldown evita ráfagas; el rate limit evita saturación sostenida (OpenDroid lo documenta; nosotros lo anclamos a identidad, no a títulos).

**Archivos nuevos:**

```
engine/scheduling/
└── contact_rate_limiter.dart   // ContactRateLimiter + ContactRatePolicy (const)
```

**Contrato:**

```dart
final class ContactRatePolicy {
  const ContactRatePolicy({
    this.maxRepliesPerWindow = 3,
    this.window = const Duration(minutes: 10),
  });
  final int maxRepliesPerWindow;
  final Duration window;
}

abstract interface class ContactRateLimiter {
  /// Consulta y registra el intento de respuesta para la clave exacta.
  /// false = bloqueado (se registra el bloqueo, NUNCA se envía).
  Future<bool> allowReply(ConversationKey key, {required DateTime at});
}

final class SharedPreferencesContactRateLimiter implements ContactRateLimiter {
  // Mismo patrón de persistencia que EventDedupeStore (JSON en shared_preferences).
}
```

**Integración:** en `RulePipeline`, después de `DedupeVerdict.fresh` y ANTES de invocar al executor. Un bloqueo de rate limit se registra en el dedupe store con estado `ignored` y razón `rate limit per-contacto (N/ventana)` — mismo trato honesto que el cooldown.

**Reglas duras:**
- La ventana se ancla a `ConversationKey.id` completo (canal+paquete+cuenta+conversación). Dos contactos homónimos jamás comparten contador.
- El registro del intento ocurre ANTES del envío (el envío puede fallar; el rate limit protege al canal, no al resultado).
- `SharedPreferencesContactRateLimiter` reusa el patrón de `EventDedupeStore` — cero esquemas nuevos de persistencia.

**Cierre:** 4 mensajes rápidos seguidos → 3 respuestas máximas, el 4.º `ignored` con razón visible en el dedupe store. Prueba física en Oppo.

---

## 4. Sprint EDGE-01 — Nano system overlay (búho)

**Objetivo:** el búho vive encima de WhatsApp (y de cualquier app) como `TYPE_ACCESSIBILITY_OVERLAY`. **Reimplementación propia del patrón** (Portal es AGPLv3: inspiración de arquitectura, cero copy-paste; el framework Mobilerun es MIT pero no se reutiliza código aquí tampoco — el overlay es simple y lo hacemos a nuestra medida).

**Archivos nuevos (Android):**

```
android/app/src/main/kotlin/dev/nanoai/mobile/edge/
├── NanoOverlayController.kt        // WindowManager + TYPE_ACCESSIBILITY_OVERLAY
├── NanoOverlayView.kt              // vista mínima: búho + panel colapsado
└── NanoOverlayBridge.kt            // MethodChannel edge.* (Flutter ↔ overlay)
```

**Archivos nuevos (Flutter):**

```
lib/features/edge/
├── nano_edge_controller.dart       // puerta Dart al canal edge.*
├── nano_edge_state.dart            // estado del overlay (colapsado/panel/contexto)
└── nano_edge_overlay.dart          // widgets del panel (NO dibuja el overlay del sistema)
```

**Contratos:**

```dart
// nano_edge_controller.dart
abstract interface class NanoEdgeController {
  Future<bool> showBubble();            // búho visible en foreground app
  Future<bool> hideBubble();
  Future<bool> showPanel(NanoEdgeState state);
  Stream<NanoEdgeEvent> get events;     // bubbleTapped, panelDismissed…
}
```

**Reglas duras:**
- El overlay solo se muestra si `AgentAccessibilityService` está conectado (sin accesibilidad no hay overlay: cero privilegios fantasma).
- El overlay NUNCA lee el árbol por sí mismo ni ejecuta gestos. Recibe `NanoEdgeState` ya resuelto (SOLID, sección 19 del análisis): `NanoOverlay → EdgeIntent → SystemContextService → ConversationAgent → AutomationCoordinator`.
- Android 12+ restringe overlays sobre apps ajenas: `TYPE_ACCESSIBILITY_OVERLAY` del servicio de accesibilidad es la vía correcta y documentada.
- El panel es Flutter-free en la primera versión: el bubble lo dibuja Android (ligero, sin arrancar Flutter); el panel completo se puede levantar después como actividad transparente.

**Cierre físico:** con WhatsApp abierto, el búho se ve encima; al tocarlo aparece el panel con el nombre de la app y el contacto. Sin accesibilidad desactivada, el búho no aparece.

---

## 5. Sprint EDGE-02 — SystemContextProvider

**Objetivo:** un solo observable de contexto del sistema para alimentar el overlay. Fusiona lo que ya existe; NO crea fuentes nuevas.

**Archivos nuevos:**

```
lib/features/edge/
└── system_context_provider.dart
```

**Contrato:**

```dart
final class SystemContextSnapshot {
  const SystemContextSnapshot({
    required this.foregroundPackage,
    this.notifications = const [],
    this.screenGraphSummary,
    this.deviceState,
    this.assistContext,
  });
  final String foregroundPackage;
  final List<NotificationObject> notifications;
  final ScreenGraphSummary? screenGraphSummary;
  final DeviceState? deviceState;
  final AssistContext? assistContext;
}

abstract interface class SystemContextProvider {
  Stream<SystemContextSnapshot> watch();
  Future<SystemContextSnapshot> current();
}
```

**Composición (solo lectura de fuentes existentes):**
- foreground + árbol → `AgentAccessibilityService` (canal existente)
- notificaciones → `NotificationAutomationService` (canal existente)
- dispositivo → `DeviceMetricsProvider` (existente)
- asistencia → `NanoVoiceInteractionService` (existente, contexto del trigger)

**Reglas duras:** solo fusión y caché con timestamp. Cero ejecución. Cero llamadas nuevas al sistema. El snapshot se anota con `observedAt` para honestidad.

**Cierre:** el overlay EDGE-01 recibe snapshots correctos al cambiar de app en el Oppo (WhatsApp → Chrome → Settings) sin tocar la app.

---

## 6. Sprint EDGE-03 — ContextPanelRegistry

**Objetivo:** resolver QUÉ panel muestra el overlay para la app en foreground. OCP puro: cada app es un perfil, no un if.

**Archivos nuevos:**

```
lib/features/edge/panels/
├── context_panel.dart          // abstract interface class ContextPanel
├── context_panel_registry.dart // resolución por paquete (const, extensible)
├── generic_context_panel.dart
├── messaging_context_panel.dart   // usa MessagingPackage + ConversationKey
├── browser_context_panel.dart
└── system_context_panel.dart
```

**Contrato:**

```dart
abstract interface class ContextPanel {
  String get id;
  bool matches(String packageName);
  Widget build(NanoEdgeState state);   // puro: recibe estado, no consulta nada
}

final class ContextPanelRegistry {
  const ContextPanelRegistry(this.panels);
  final List<ContextPanel> panels;   // orden = prioridad; Generic siempre al final
  ContextPanel resolve(String packageName);
}
```

**Reglas duras:**
- `MessagingContextPanel` reconoce `MessagingPackage.known` (ya anclado en UNI-01). WhatsApp NO conoce el widget; el widget conoce el paquete (OCP correcto).
- Paneles son widgets puros (presentación). Cero imports de execution/governance.
- El contexto conversacional (contacto, resumen) llega por `NanoEdgeState`, resuelto por `SystemContextProvider` + `ConversationMemoryStore` existentes.

**Cierre:** en Oppo, con WhatsApp en foreground el panel muestra acciones de mensajería; con Settings muestra acciones de sistema; con cualquier app rara muestra el panel genérico.

---

## 7. Sprint WA-MIRROR-01 — Conversation Mirror

**Objetivo:** dentro del panel de mensajería, un espejo de la conversación actual: historial, resumen y búsqueda. Supera la limitación documentada de Gemini (no lee historial de WhatsApp) usando SOLO lo que Nano ya observa legalmente: `ConversationMemoryStore` (eventos de notificación) + ScreenGraph (lo visible en pantalla).

**Archivos nuevos:**

```
lib/features/edge/panels/
├── conversation_mirror.dart      // widget: pestañas Historial / Resumen / Buscar
└── conversation_search.dart      // búsqueda semántica local sobre la memoria
```

**Contrato:**

```dart
// conversation_mirror.dart
final class ConversationMirror {
  const ConversationMirror({required this.store});
  final ConversationMemoryStore store;
  Future<ConversationMirrorData> load(ConversationKey key);  // entradas + límites
  Future<String> summarize(ConversationKey key);             // LLM local, prompt acotado
  Future<List<MemoryEntry>> search(ConversationKey key, String query);
}
```

**Reglas duras:**
- Historial = SOLO `ConversationMemoryStore` + ScreenGraph visible. NUNCA scraping no autorizado del almacén de WhatsApp.
- Fotos/audios: primera versión muestra metadatos observables (presencia de adjuntos en notificaciones); contenido multimedia queda como sprint futuro honesto, no se finge.
- Resumen usa el LLM local con el mismo contrato estricto del supervisor Koog (malformado → abstain, jamás inventa).
- El mirror es lectura pura. Cero capacidades de escritura en este sprint.

**Cierre físico:** con el overlay abierto sobre un chat de Emm, Historial muestra las entradas inbound/outbound reales de la certificación WA-PHYS-11; Resumen produce texto coherente; Buscar encuentra «Nano E2E».

---

## 8. Sprint SKILL-01 — SkillExtractor

**Objetivo:** convertir trazas VERIFICADAS del `ExecutionJournal` en skills semánticas reutilizables. Nunca taps crudos (sección 10 del análisis).

**Archivos nuevos:**

```
engine/skills/
├── skill.dart                 // Skill = id + preconditions + steps + postconditions
├── skill_extractor.dart       // traza verificada → draft skill
├── skill_store.dart           // persistencia shared_preferences (patrón existente)
└── verified_skill.dart        // skill aprobada por el usuario (estado)
```

**Contrato:**

```dart
final class Skill {
  const Skill({
    required this.id,
    required this.preconditions,
    required this.steps,
    required this.expectedPostconditions,
  });
  final String id;
  final List<SkillCondition> preconditions;        // semánticas, no coordenadas
  final List<SemanticSkillStep> steps;             // conversation.write(text), conversation.send()
  final List<SkillCondition> expectedPostconditions;
}

abstract interface class SkillExtractor {
  /// Solo trazas con TODOS los pasos en estado verified (o completed con
  /// evidencia localSendVerified). outcomeUnknown/fallidas → null.
  Skill? extract(ExecutionJournalEntry verifiedTrace);
}
```

**Reglas duras:**
- Solo trazas verificadas entran. `outcomeUnknown` jamás genera skill.
- Pasos semánticos referencian superficies (`SurfaceElementKind`) y capabilities (`CapabilityIntent`) — jamás coordenadas.
- Draft skills requieren aprobación explícita del usuario antes de ser ejecutables (`verified_skill.dart`).
- La ejecución de una skill pasa por el MISMO Policy → Journal → CommitGuard. Skills no son un atajo.

**Cierre:** una tarea verificada de "responder en WhatsApp" produce un draft skill con pre/postcondiciones legibles; requiere aprobación manual; no se ejecuta sola.

---

## 9. Sprint APPFN-01 — AppFunctions fast path (oportunista)

**Objetivo:** preparar el quinto camino del CapabilityResolver sin depender de él. Android 16+ y experimental: fast path oportunista, jamás requisito.

**Archivos nuevos (Android):**

```
android/app/src/main/kotlin/dev/nanoai/mobile/appfunctions/
├── AppFunctionProbe.kt        // detecta disponibilidad (SDK >= 36 + permiso)
└── AppFunctionChannelHandler.kt // canal appfunctions.* (solo consulta en v1)
```

**Reglas duras:**
- `EXECUTE_APP_FUNCTIONS` solo se declara si el sistema lo soporta (manifest con `android:required="false"` conceptualmente; en la práctica: feature probe en runtime).
- En v1 NO se ejecuta ninguna AppFunction: el probe solo reporta disponibilidad para que `CapabilityResolver` pueda puntuar el camino. La ejecución real llega cuando Android estabilice la API y se valide físicamente en el Oppo.
- Si el Oppo no lo soporta: `none` con razón honesta, y la política lo documenta.

**Cierre:** el probe reporta correctamente disponible/no disponible en el Oppo (ColorOS, Android 15 probablemente → no disponible = camino correctamente cerrado).

---

## 10. Sprint ROLE-01 — Assistant role

**Objetivo:** cuando el usuario quiera, Nano puede pedir ser asistente por defecto (ROLE_ASSISTANT, API 29+). La base ya existe: `NanoVoiceInteractionService` + `BIND_VOICE_INTERACTION` en el manifest.

**Archivos:**

```
lib/features/edge/assistant_role.dart   // solicitud de role vía canal Android existente
```

**Contrato:**

```dart
abstract interface class AssistantRoleManager {
  Future<bool> isHoldingRole();        // consulta sin solicitar
  Future<bool> requestRole();          // abre el diálogo del sistema (nunca fuerza)
}
```

**Reglas duras:**
- NUNCA solicitar el role automáticamente. Solo un botón explícito del usuario en la app ("Hacer Nano mi asistente").
- Si el usuario niega: estado honesto en la UI, sin reintentos silenciosos.

**Cierre:** en el Oppo, el botón abre el selector del sistema; negar no rompe nada.

---

## 11. Orden de ejecución y dependencias

```
CAP-ROUTER-01 ──► RATE-01 ──► EDGE-01 ──► EDGE-02 ──► EDGE-03 ──► WA-MIRROR-01
                                                                        │
                                              SKILL-01 ◄──(trazas)──────┘
                                              APPFN-01 (paralelo, independiente)
                                              ROLE-01  (paralelo, independiente)
```

- CAP-ROUTER-01 primero: el router es el punto donde TODOS los caminos futuros se enchufan sin tocar ejecutores.
- RATE-01 antes del edge: protege el canal antes de exponer más superficie de automatización.
- EDGE-01/02/03 en cadena: overlay sin contexto no muestra nada; contexto sin overlay no se ve.
- WA-MIRROR-01 depende de EDGE-03 (vive dentro del panel) y de la memoria existente.
- SKILL-01 y APPFN-01/ROLE-01 independientes entre sí.

## 12. Reglas de calidad por sprint (para TODOS)

1. **Sin tests automatizados nuevos** — validación manual en el Oppo (metodología del proyecto).
2. **Cierre de cada sprint =** `flutter analyze` 0 errores + commit con mensaje `feat(...)`/`fix(...)` descriptivo + evidencia física cuando aplique.
3. **Sin duplicados:** antes de crear una clase, grep por su responsabilidad. Si existe (aunque se llame distinto), se reutiliza y se documenta el mapeo en el header del archivo nuevo (patrón UNI-01).
4. **Sin dañar lógica real:** prohibido editar `AutomationCoordinator`, `PolicyEngine`, `ToolRegistry`, `ExecutionJournal`, `CommitGuard`, `NanoAgentExecutor`, `ActionVerifier`. Los sprints añaden capas ALREDEDOR (observación/selección/presentación), nunca DENTRO de la cadena de autoridad.
5. **Honestidad:** todo estado intermedio se nombra con el vocabulario existente (`dispatchedUnverified`, `outcomeUnknown`, `completedUnverified`). Prohibido reportar `verified` sin evidencia física.
6. **Ramas:** un `feat/edge-*` por sprint sobre `master`; merge fast-forward solo si `master` es ancestro limpio; push a origin al cerrar.
7. **Prueba física obligatoria por grupo de sprints** (metodología vigente): overlay visible, rutas correctas, rate limit visible en dedupe store.

## 13. Meta final medible (tras todos los sprints)

```
0 destinatarios incorrectos
0 duplicados ciegos
0 falsos verified
0 bypass de Policy/Journal
1 solo dueño de efectos (AutomationCoordinator)
N apps universales con el MISMO motor (WhatsApp primero)
```
