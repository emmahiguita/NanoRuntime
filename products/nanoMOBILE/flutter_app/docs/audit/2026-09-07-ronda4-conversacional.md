# NANO AI — Ronda 4: Motor de Conversación Humana — Informe Final

Fecha: 2026-09-07 · Rama: master · Estado: implementado, validación física pendiente (C01-C30)

Metodología ejecutada en orden: INSPECCIONAR → RECONSTRUIR → MEDIR → DIAGNOSTICAR →
DEMOSTRAR → DISEÑAR CAMBIO MÍNIMO → IMPLEMENTAR → COMPILAR → INSPECCIONAR DIFF →
VALIDAR FÍSICAMENTE (pendiente, usuario en Oppo). Sin tests creados (metodología del
proyecto: validación manual en dispositivo). Sin instalar frameworks externos.

---

## 1. INVESTIGACIÓN EXTERNA

Matriz de patrones estudiados (fuentes citadas; nada instalado — INSTALAR=NO siempre):

| Proyecto | Patrón | Problema que resuelve | Equivalente Nano | Adaptar | Instalar |
|---|---|---|---|---|---|
| Rasa CALM | Dialogue Understanding (LLM emite COMANDOS internos, no texto final); Flow Policy determinista ejecuta; diálogo stack LIFO; repair automático (digresión, corrección, cancelación, aclaración) | LLM no decide negocio: entiende, el estado determinista ejecuta | `ConversationUnderstanding` (JSON) + `ConversationDecisionEngine` (código decide) + relación corrige/rechaza | Repair como SEÑALES de decisión (relation), no como flows | NO |
| LangGraph/LangChain | Memoria en 2 capas: thread-scoped (historial corto) vs Store con namespaces (largo plazo); trimming por conteo/tokens; recuerdo cross-thread al abrir conversación | Historial no desborda contexto; memoria larga no contamina turnos | ConversationMemoryStore (corta) + convstate SQLite (larga) + gate determinista | MEMORIA DISPONIBLE != RELEVANTE ya implementado | NO |
| Letta | Memory blocks adjuntables/desadjuntables; tiers core/recall/archival; bloques con cap de tamaño | Control de qué memoria ENTRA al contexto por turno | Bloques de prompt gateados por rol (business/persona/clientContext) con validator acotado | attach/detach = gates por rol existentes | NO |
| OpenAI Agents SDK | Guardrails de salida (tripwire post-hoc); handoff transfiere ownership; output estructurado con schema; maxTurns acota loops | Política no vive en el prompt: valida después del modelo | P0-NO-CALLCENTER (guard determinista post-draft) + ownership humana | Guard post-draft es el MISMO patrón | NO |
| Chatwoot | Ownership por estado de conversación (pending=bot, open=humano); handoff bot↔humano explícito; bot sigue en el loop tras handoff | El bot jamás pisa al humano y el humano devuelve el turno | ConversationOwnershipStore + holdForApproval (needsHuman) | Ownership ya implementado | NO |
| Semantic Kernel | Decisión explícita de cuándo NO orquestar: un solo agente con instrucciones claras si el objetivo es único; orquestación = lógica de aplicación | Multi-agente innecesario encarece y des-determiniza | Un solo motor, un solo prompt, roles como GATES | Reafirma: sin segundo loop, sin group-chat (invariante del brief) | NO |

Fuentes: [Rasa Command Generator](https://rasa.com/docs/pro/customize/command-generator/),
[Flow Policy](https://rasa.com/docs/reference/config/policies/flow-policy/),
[Letta memory blocks](https://docs.letta.com/tutorials/attaching-detaching-blocks),
[Letta stateful agents](https://docs.letta.com/guides/core-concepts/stateful-agents),
[LangGraph memory](https://docs.langchain.com/oss/python/concepts/memory),
[OpenAI Agents SDK handoffs](https://futureagi.com/blog/what-is-openai-agents-sdk-2026/),
[Chatwoot agent bots](https://www.chatwoot.com/hc/user-guide/articles/1677497472-how-to-use-agent-bots),
[SK multi-agent orchestration ADR](https://github.com/microsoft/semantic-kernel/blob/vectordata-dotnet-9.6.0/docs/decisions/0071-multi-agent-orchestration.md).

## 2. INGENIERÍA INVERSA

Pipeline real (nombres confirmados en código, cadena file:line):

1. `NotificationAutomationService.kt:52` `onNotificationPosted` → EventChannel `com.nanoai/notification_events`
2. `notification_event_router.dart:27` (echo guard `sender='Tú'` en 57-61)
3. `burst_turn_gate.dart` `submit` (settle 800ms / máx 3s / cap 6, serialización por conversación, bump supersede por batch)
4. `rule_pipeline.dart:93` `onNotification` (reserve :119, bounceback :138, flush :181)
5. `rule_dispatcher.dart:242` `dispatch` (draftSource :279, decide :309-331, verificación supersede :353-367, execute :383)
6. `automation_coordinator.dart:748` `execute` → `agent_tool_dispatcher.dart:2194` `_replyNotification` → `nano_runtime_api.dart:1147` `replyToNotification` → `NotificationAutomationService.kt:107` (RemoteInput, revalidación WA-RI-05)
7. `reconcile :2218` → `rule_pipeline.dart:235` terminal + `ConversationMemoryStore` appendInbound/appendOutbound

Ciclo de estado por turno: `BurstTurnGate.onInbound` → bump versión; `onTurnComplete` →
`ConversationStateNotifier.recordTurn` (producto + pregunta pendiente + tema).

Ciclo LLM: `RuntimeNotificationDraftWriter.write` → prompt completo o social mínimo →
`generateWithColdRetry` (sessionId por turno) → `parseConversationUnderstanding`
(JSON completo → reply recuperable → legacy "Respuesta:" → null honesto) →
`ConversationDecisionEngine.decide` → dispatcher.

## 3. CAUSA RAÍZ

| Hallazgo | Evidencia | Severidad | Confirmado | Owner |
|---|---|---|---|---|
| G1: `_socialWindow` admitía outbound huérfano (sin inbound social previo) | `notification_draft_writer.dart` (rama `else` incondicional) | Media | SÍ (código) | Writer |
| G2: bloque persona con framing "Preséntate como su asistente" contradice regla 5 del prompt | `persona_context.dart:86` | Alta | SÍ (código) | PersonaContext |
| G3: respuesta corta a pregunta pendiente ("M", "mañana") caía a GENERAL y el bloque `<PREGUNTA PENDIENTE>` jamás entraba | router sin rama pendingQuestion; writer gatea clientContext por rol sales/commercialIntent | Alta | SÍ (código) | Router+Writer |
| G4: corrección/rechazo no invalidaba el recuerdo de producto ni el tema activo | `recordTurn` sin señal de corrección; "sí" posterior reactivaba producto deshecho | Alta | SÍ (código) | ConversationStateNotifier |
| G5 | = G2 (duplicado del hallazgo) | — | — | — |
| G6: guard P0-NO-CALLCENTER solo cubría PERSONAL; GENERAL seguía despachando muletillas de operador | `conversation_decision_engine.dart:106` | Media | SÍ (código) | DecisionEngine |
| G7: sin traza de la relación semántica — los fallos de continuidad eran invisibles en logcat | grep de trazas: `[route]`, `[ctx:gate]`, `[draft:*]` sin `[understanding]` | Baja | SÍ (código) | Writer |
| G8: relation corrige/rechaza solo degradaba 0.15 → 0.70 ≥ 0.6 seguía enviando afirmaciones sobre contexto deshecho | `conversation_decision_engine.dart:178-185` | Alta | SÍ (código) | DecisionEngine |
| KV/session sano | `turnSession = conversationId|fingerprint` único por turno (writer:316); Rust gate R5 reuse_kv exige misma session_id (model_manager.rs:1548-1555) → prefill limpio siempre; prefix cache V1.1 amortiza el estático (orchestrator mod.rs:888-896); retry frío conserva la MISMA sesión | — | SÍ (auditado) | Motor |

## 4. PROBLEMAS CONFIRMADOS

G1, G2, G3, G4, G6, G7, G8 (tabla anterior). Ningún hallazgo de KV/session ni de
`_inFlight` (invariante ONE LOGICAL INPUT = ONE DRAFT se sostiene: `_inFlight`
estático keyed por conversationId|fingerprint en el writer + verificación de
supersede post-draft y pre-ejecución en el dispatcher).

## 5. HIPÓTESIS DESCARTADAS

- H2 parcialmente: la continuidad social existía (`_socialWindow`) pero con el bug G1 (outbound huérfano). Corregido, no reconstruido.
- H3 parcialmente: `relation` ya existía (CONV-SEM-01 en el working tree previo); no se añadieron acts/dominios/entidades — el brief §38 permite esquema compacto.
- H5 parcialmente: pendingKind por keyword sigue siendo la fuente; "¿M o L?" sin tokens de expectativa queda sin kind. Aceptado como riesgo restante (el hint genérico de la pregunta completa llega igual al prompt).

## 6. CONVERSATION UNDERSTANDING

Estructurado JSON (1 pasada LLM): `{intent, relation, reply, questions, missingFacts, requiresAction}`.
Parser 3 escalones (JSON completo → reply recuperable → legacy). `relation` en
vocabulario cerrado ('nuevo'|'continua'|'responde'|'cambia'|'corrige'|'rechaza'|'').
Nuevo: traza `[understanding]` con relation/intent/counts/requiresAction (G7).

## 7. DIALOGUE STATE

`ClientContextEntry` por conversación (sección `convstate` SQLite): producto recordado,
pregunta pendiente + `pendingKind` ('confirm'|'value'), `topicStatus`
('active'|'resolved'|''). Nuevo: invalidación por corrección (G4) — `recordTurn`
acepta `correction` y limpia producto+tema; la señal viene de `isCorrectionMessage`
en `onTurnComplete` (misma fuente del router, cero LLM).

## 8. AGENT ROUTING

`routeConversationAgent` determinista (raw text + estado; jamás el LLM — invariante
ROUTER != FULL NLU). 13 ramas ordenadas: corrección → identidad → rechazo de ayuda →
queja → comercial (producto+señal) → saludo puro → referencia/producto activo →
**respuesta a pregunta pendiente (nueva)** → casual corto → reacción social →
familia → relación → general. Nueva señal `hasPendingQuestion` alimentada por
`routeFor` y `decisionContext` con la MISMA evidencia (convstate). `pendingReply`
viaja en el routing para el gate del writer.

## 9. PERSONAL AGENT

Rol PERSONAL = estilo del dueño, prompt social mínimo para saludos/reacciones,
prompt completo con MI ESTILO/TONO/PERSONA para el resto. `pendingReply` abre el
bloque `<PREGUNTA PENDIENTE>` en turnos personales (G3): es diálogo del propio
dueño, no contexto de negocio.

## 10. SALES AGENT

Sin cambios de lógica: rol SALES = `<DATOS DEL NEGOCIO>` (selector léxico
WA-BUSINESS-02) + `<CONTEXTO DEL CLIENTE>`. Nueva ruta de entrada: "la negra"
como respuesta a pregunta de elección pendiente → SALES (los facts del producto
activo resuelven la elección).

## 11. CONTEXT FIREWALL

Intacto y reforzado: `<CONTEXTO DEL CLIENTE>` entra solo con rol sales,
commercialIntent o `pendingReply` (nuevo). El gate determinista
`clientContextBlockForTurn` (7 reglas) decide el CONTENIDO; el rol decide la
ENTRADA. NO COMMERCIAL INTENT = NO SALES CONTEXT se mantiene.

## 12. SOCIAL CONTINUITY

`_socialWindow` corregida (G1): cada outbound exige su inbound social previo;
outbound huérfano fuera; bandera se reinicia tras cada par. Ventana máx 2
entradas. Historial limpio en corrección (P0-CORRECTION existente).

## 13. PERSONA

Framing corregido (G2): "El dueño es X; responde como lo haría él. Jamás te
presentes como asistente… Solo si preguntan explícitamente quién eres, responde
tu nombre: Nano." — alineado con regla 5 del prompt. PERSONA != FACT SOURCE:
el bloque sigue instruyendo "jamás inventes datos a partir de ellos".

## 14. RELATIONSHIP

Sin cambios: `hasRelationshipFor` (clave normalizada por nombre) → PERSONAL en
el router; notas de relación viajan en `<DATOS DE LA PERSONA>`.

## 15. MEMORY

Sin cambios estructurales: `ConversationMemoryStore` (corta, bounded 3×80 chars
por WA-UNIV-03) + convstate (larga, gateada). CONTEXT MUST BE PULLED: todo
recuerdo entra por gate determinista, jamás por defecto.

## 16. EXPECTED REPLY

`pendingQuestion` sigue naciendo solo de reply con '?' + token de expectativa
(P1-FIX, Ronda 3). El consumo nuevo es G3: el valor libre ("M") ahora llega al
modelo CON la pregunta pendiente en el prompt, en turno personal.

## 17. CONTEXT REPAIR

Nuevo comportamiento determinista (G8): relation corrige/rechaza + reply
ASERTIVO → holdForApproval (invariante UNKNOWN OUTCOME != SUCCESS); + reply
PREGUNTA → confianza -0.15 y sigue (pedir el dato correcto es la reparación
honesta). El estado invalida producto+tema (G4). "¿cuál negro de qué hablas?"
ya entraba con historial limpio (P0-CORRECTION).

## 18. KV/SESSION

Auditado sano (sin cambios): sessionId = conversationId|fingerprint → único por
turno → gate R5 del Rust (reuse_kv exige misma session_id + kv_valid + template
hash) → prefill limpio cada turno (forense eco Negro: KV entre turnos era
reutilización indebida). Prefix cache V1.1 (Rust, orchestrator) amortiza el
prefill estático sin exponer KV entre turnos. Retry frío conserva la misma
sesión (mismo turno). `mark_session_cancelled` invalida sesión cancelada.

## 19. TURN OWNERSHIP

Sin cambios: `_inFlight` keyed por conversationId|fingerprint; supersede guard
con versión monotónica por conversación (bump en inbound, verificación post-draft
y pre-ejecución). ONE LOGICAL INPUT = ONE DRAFT se mantiene.

## 20. BURST

Sin cambios: settle 800ms / tope 3s / cap 6, agregación por conversación,
`onIdle` solo con bucket vacío (WA-TURN-01/WA-REG-01).

## 21. RULE ENTRYPOINT

Sin cambios: RulePipeline (reserve/bounceback/flush) → RuleDispatcher
(draftSource → decide → supersede → execute). El dispatch es el ÚNICO punto
de decisión de envío.

## 22. DECISION ENGINE

Dos cambios: (a) G6 — guard P0-NO-CALLCENTER extendido a GENERAL; (b) G8 —
corrige/rechaza con reply asertivo retiene. Cadena intacta: ownership →
autonomía → identidad 0.95 → call-center guard → requiresAction/missingFacts →
intent vacío → relation → umbral 0.6 → safeAuto gate.

## 23. BUGS

Ninguno nuevo introducido (0 issues de analyze en lib/). G1-G8 cerrados.

## 24. RACES

Sin razas nuevas: todos los cambios son (a) deterministas síncronos puros, (b)
un param en `recordTurn` (ya serializado por conversación), (c) trazas. La
única carrera conocida documentada (REVIEW-01 TOCTOU orchestrator) sigue
pendiente y sin tocar.

## 25. PROCESOS ZOMBI

Audit zombie de lo nuevo: **cero** Future/Timer/Stream/retry/DB-write nuevos.
G3 añade lectura de estado; G4 añade un param a un write existente; G7 añade
`debugPrint` síncrono. Ningún ciclo de vida nuevo que rastrear.

## 26. TASK/TIMEOUT

Sin tareas ni timeouts nuevos. `ensureReady` 60s y retry frío intactos.

## 27. DUPLICADOS

Sin duplicación nueva: `hasPendingQuestion` se calcula UNA vez por sitio de
routing y se pasa por param (misma expresión en ambos callers, no un helper
duplicado — dos líneas idénticas aceptadas para no acoplar capas).
`isCorrectionMessage` se reutiliza (única fuente en role.dart).

## 28. COMPONENTES SIN LÓGICA

Ninguno nuevo. `ConversationAgentRouting.pendingReply` es dato, no lógica.

## 29. CUELLOS DE BOTELLA

Sin cambios: una pasada LLM por turno; prompt compacto (WA-CTX-01); prefix
cache; social prompt mínimo para saludos (128 tokens vs 320). La traza
`[understanding]` es una línea por turno (sin costo medible).

## 30. SOLID/CLEAN

Cambios mínimos por archivo, cada uno con UNA responsabilidad: rol (señal de
routing), writer (gates de prompt + traza), state (invalidación), engine
(decisión), persona (framing). Sin imports circulares nuevos
(engine no importa personal_agent; la señal de corrección entra por param).

## 31. ARCHIVOS MODIFICADOS

1. `lib/features/automation/personal_agent/domain/conversation_agent_role.dart` — campo `pendingReply`, param `hasPendingQuestion`, rama de respuesta a pregunta pendiente (12→13 ramas).
2. `lib/features/automation/engine/agent_dependencies.dart` — `routeFor` pasa `hasPendingQuestion` (format reordenó imports `show`).
3. `lib/features/automation/engine/notifications/notification_draft_writer.dart` — gate clientContext con `pendingReply` (G3), `_socialWindow` corregida (G1), traza `[understanding]` (G7).
4. `lib/features/automation/engine/messaging/conv_turn_state.dart` — `recordTurn` acepta `correction` e invalida producto+tema (G4).
5. `lib/features/automation/application/automation_coordinator_provider.dart` — `decisionContext` pasa `hasPendingQuestion`; `onTurnComplete` pasa `correction: isCorrectionMessage(text)` (G4).
6. `lib/features/automation/personal_agent/application/conversation_decision_engine.dart` — guard call-center a GENERAL (G6); corrige/rechaza asertivo retiene (G8).
7. `lib/features/automation/personal_agent/application/persona_context.dart` — framing del dueño sin "asistente" (G2).
8. `PRUEBAS_MANUALES_SPRINTS.md` — sección Ronda 4 + matriz C01-C30.

## 32. QUÉ NO SE TOCÓ

Prompts (salvo cero cambios de texto: los prompts ya estaban alineados tras
CONV-PROMPT-01), BurstTurnGate, RulePipeline/Dispatcher, supersede guard,
ConversationMemoryStore, KV/session (Rust y Flutter), business facts y selector,
tone profile, settings, UI, tests preexistentes (75 issues de analyze en test/
son preexistentes y NO se corrigen por metodología).

## 33. ANALYZE

`flutter analyze`: 75 issues, TODOS en `test/` (preexistentes). 0 errores y
0 warnings en `lib/`. `dart format` aplicado (1 archivo reordenó imports).

## 34. KOTLIN COMPILE

`compileDebugKotlin`: OK (solo warning preexistente de SDK XML v4).

## 35. RELEASE BUILD

`flutter build apk --release`: en curso al cierre del informe (ver resultado
del build en la sesión). Sin él, NO se instala nada (metodología: build limpio
antes de validar).

## 36. PRUEBAS MANUALES A EJECUTAR

Matriz C01-C30 completa en `PRUEBAS_MANUALES_SPRINTS.md` (sección Ronda 4).
Núcleo decisivo: C06 ("M" resuelve contra pregunta pendiente), C08/C09
(corrección invalida contexto), C16/C17 (corrige asertivo retiene / pregunta
envía), C20 (general sin muletillas), C25 (sessionId distinto por turno).

## 37. RIESGOS RESTANTES

- pendingKind sigue por keyword: "¿M o L?" sin token de expectativa queda sin
  hint tipado (el prompt recibe la pregunta completa igual — riesgo bajo).
- C24 depende de hidratación de convstate en arranque frío (barrera global
  storesHydrated) — verificar en físico.
- La traza `[understanding]` y `[ctx:gate]` son TEMPORALES (quitar tras M01-M10/
  C01-C30) — recordar purgar.
- Validación física pendiente: sin evidencia en dispositivo no se da por DONE
  (definición de hecho del brief).

## 38. SIGUIENTE SPRINT

Candidatos ordenados: (1) validación física C01-C30 en Oppo y cierre de los que
fallen; (2) WA-BUSINESS-02.2 — mapeo flush pre-send (3 sitios de envío
identificados, pendiente); (3) purga de trazas temporales tras validar;
(4) WA-STATE-02 — multi-entidad en el recuerdo estructurado.
