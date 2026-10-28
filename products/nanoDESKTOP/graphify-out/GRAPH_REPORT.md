# Graph Report - nanoDESKTOP  (2026-10-14)

## Corpus Check
- 84 files · ~70,253 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 747 nodes · 1298 edges · 53 communities (39 shown, 14 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.64)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `011b359e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- agent_service.js
- NanoIcon
- transport.js
- LocalRuntimeBridge
- .get
- RuntimeService
- WhatsAppChatConversation
- ShellManager
- AgentService
- PtySession
- OwlStateMachine
- RuntimeSupervisor
- StateManager
- TerminalService
- definitions
- definitions
- NanoOwlAvatar
- tauri.conf.json
- properties
- properties
- permissions
- webviews
- permissions
- webviews
- App
- WhatsAppSessionManager
- CapabilityRemote
- CapabilityRemote
- ChatHeroView
- WhatsAppAiAgent
- desktop-schema.json
- windows-schema.json
- Capability
- description
- Capability
- description
- ShellAdapter
- theme.js
- ShellScopeEntryAllowedArg
- ShellScopeEntryAllowedArgs
- ShellScopeEntryAllowedArg
- ShellScopeEntryAllowedArgs
- ICONS
- ChatComposer
- ShellScopeEntryAllowedArg
- ChatHeroView
- WhatsAppChatConversation
- WhatsAppChatList
- HardwareStatus
- Capability

## God Nodes (most connected - your core abstractions)
1. `ShellManager` - 21 edges
2. `AgentService` - 21 edges
3. `NanoIcon` - 19 edges
4. `PtySession` - 18 edges
5. `escapeHtml()` - 18 edges
6. `NanoOwlAvatar` - 16 edges
7. `StateManager` - 16 edges
8. `RuntimeService` - 14 edges
9. `AutomationView` - 14 edges
10. `WhatsAppStorage` - 14 edges

## Surprising Connections (you probably didn't know these)
- `LocalRuntimeBridge` --uses--> `RuntimeJob`  [INFERRED]
  local_runtime_bridge.py → windows_runtime_job.py
- `handle_local_route()` --calls--> `installed_models()`  [EXTRACTED]
  local_model_routes.py → local_model_catalog.py
- `RuntimeService` --references--> `RuntimeSupervisor`  [EXTRACTED]
  src-tauri/src/runtime/service.rs → src-tauri/src/runtime/supervisor.rs
- `ShellManager` --references--> `PtySession`  [EXTRACTED]
  src-tauri/src/shell/manager.rs → src-tauri/src/shell/session.rs
- `loadAgentState()` --indirect_call--> `getDefaultAgents()`  [INFERRED]
  ui/js/features/automation/agent_persistence.js → ui/js/features/automation/automation_defaults.js

## Import Cycles
- None detected.

## Communities (53 total, 14 thin omitted)

### Community 0 - "agent_service.js"
Cohesion: 0.07
Nodes (25): memoryStore, formatRelativeTime(), approveAction(), deferExecution(), executeAgent(), fingerprint(), needsApproval(), rejectAction() (+17 more)

### Community 1 - "NanoIcon"
Cohesion: 0.07
Nodes (16): whatsAppBus, WhatsAppEventBus, WhatsAppEvents, AutoReplyPolicy, ConversationThread, MessageDirection, MessageStatus, SessionStatus (+8 more)

### Community 2 - "transport.js"
Cohesion: 0.22
Nodes (3): readSessions(), writeSessions(), StateManager

### Community 3 - "LocalRuntimeBridge"
Cohesion: 0.06
Nodes (32): ProxyAndStaticHandler, installed_models(), Catálogo del PC: archivos GGUF existentes, nunca nombres de modelos inventados., Lee solo cabeceras y tamaños; excluye placeholders sin cargar pesos en RAM., Una petición solo puede activar un recurso que sigue existiendo en este catálogo, resolve_model(), handle_local_route(), Rutas locales del servidor Desktop: catálogo, selección y conversación reales. (+24 more)

### Community 4 - ".get"
Cohesion: 0.06
Nodes (21): NanoCommandBar, FEATHER_ICONS, NanoIcon, NanoTopBar, calculateModelFit(), appState, transport, escapeHtml() (+13 more)

### Community 5 - "RuntimeService"
Cohesion: 0.07
Nodes (38): Into, ChatInput, ChatOutput, DoneEventPayload, emit_chat_error(), ErrorEventPayload, nano_chat_prompt(), nano_chat_prompt_stream() (+30 more)

### Community 7 - "ShellManager"
Cohesion: 0.14
Nodes (18): HashMap, Mutex, nano_pty_close(), nano_pty_open(), nano_pty_resize(), nano_pty_write(), AppHandle, Arc (+10 more)

### Community 8 - "AgentService"
Cohesion: 0.17
Nodes (6): activateLocalModel(), listLocalModels(), streamNativeChat(), streamChatPrompt(), waitWithSignal(), TransportClient

### Community 9 - "PtySession"
Cohesion: 0.12
Nodes (18): Box, Child, CommandBuilder, Drop, MasterPty, NativePtyShell, PtyExitPayload, PtyOutputPayload (+10 more)

### Community 10 - "OwlStateMachine"
Cohesion: 0.14
Nodes (5): OWL_ASSETS, OWL_PHYSICS_CONFIG, OWL_TIMERS_CONFIG, OwlPhysicsEngine, OwlStateMachine

### Community 11 - "RuntimeSupervisor"
Cohesion: 0.17
Nodes (14): NanoRuntime, Sender, ensure_engine(), Arc, Default, Option, Receiver, Response (+6 more)

### Community 12 - "StateManager"
Cohesion: 0.21
Nodes (3): NanoOverlay, WhatsAppPairingModal, WhatsAppView

### Community 14 - "definitions"
Cohesion: 0.13
Nodes (15): definitions, Identifier, Number, PermissionEntry, Target, Value, oneOf, anyOf (+7 more)

### Community 15 - "definitions"
Cohesion: 0.13
Nodes (15): definitions, Identifier, Number, PermissionEntry, Target, Value, oneOf, anyOf (+7 more)

### Community 17 - "tauri.conf.json"
Cohesion: 0.17
Nodes (11): app, security, windows, withGlobalTauri, build, frontendDist, identifier, productName (+3 more)

### Community 18 - "properties"
Cohesion: 0.18
Nodes (11): properties, description, type, default, description, type, identifier, local (+3 more)

### Community 19 - "properties"
Cohesion: 0.18
Nodes (11): properties, description, type, default, description, type, identifier, local (+3 more)

### Community 20 - "permissions"
Cohesion: 0.20
Nodes (10): $ref, description, items, type, uniqueItems, description, items, type (+2 more)

### Community 21 - "webviews"
Cohesion: 0.20
Nodes (10): type, webviews, windows, items, description, items, type, description (+2 more)

### Community 22 - "permissions"
Cohesion: 0.20
Nodes (10): $ref, description, items, type, uniqueItems, description, items, type (+2 more)

### Community 23 - "webviews"
Cohesion: 0.20
Nodes (10): type, webviews, windows, items, description, items, type, description (+2 more)

### Community 26 - "CapabilityRemote"
Cohesion: 0.25
Nodes (8): description, properties, required, type, CapabilityRemote, urls, description, type

### Community 27 - "CapabilityRemote"
Cohesion: 0.25
Nodes (8): description, properties, required, type, CapabilityRemote, urls, description, type

### Community 28 - "ChatHeroView"
Cohesion: 0.29
Nodes (6): Cambios visuales y responsabilidades, Fuentes y documentación existente, Nano Desktop · mensajería y conexión oficial, Orden seguro para completar la integración, Qué está conectado y qué no, Verificación realizada

### Community 30 - "desktop-schema.json"
Cohesion: 0.40
Nodes (4): anyOf, description, $schema, title

### Community 31 - "windows-schema.json"
Cohesion: 0.40
Nodes (4): anyOf, description, $schema, title

### Community 33 - "description"
Cohesion: 0.50
Nodes (4): default, description, type, description

### Community 35 - "description"
Cohesion: 0.50
Nodes (4): default, description, type, description

### Community 36 - "ShellAdapter"
Cohesion: 0.50
Nodes (3): Send, Sync, ShellAdapter

### Community 37 - "theme.js"
Cohesion: 0.83
Nodes (3): restoreNanoTheme(), setNanoTheme(), toggleNanoTheme()

### Community 38 - "ShellScopeEntryAllowedArg"
Cohesion: 0.50
Nodes (4): description, required, type, Capability

### Community 39 - "ShellScopeEntryAllowedArgs"
Cohesion: 0.67
Nodes (3): ShellScopeEntryAllowedArgs, anyOf, description

### Community 40 - "ShellScopeEntryAllowedArg"
Cohesion: 0.67
Nodes (3): ShellScopeEntryAllowedArg, anyOf, description

### Community 41 - "ShellScopeEntryAllowedArgs"
Cohesion: 0.67
Nodes (3): ShellScopeEntryAllowedArgs, anyOf, description

### Community 47 - "ShellScopeEntryAllowedArg"
Cohesion: 0.67
Nodes (3): ShellScopeEntryAllowedArg, anyOf, description

### Community 52 - "Capability"
Cohesion: 0.50
Nodes (4): description, required, type, Capability

## Knowledge Gaps
- **106 isolated node(s):** `$schema`, `title`, `description`, `anyOf`, `description` (+101 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NanoIcon` connect `.get` to `NanoIcon`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Why does `escapeHtml()` connect `.get` to `NanoIcon`, `WhatsAppChatList`, `WhatsAppChatConversation`, `WhatsAppChatConversation`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `AgentService` connect `agent_service.js` to `.get`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **What connects `Catálogo del PC: archivos GGUF existentes, nunca nombres de modelos inventados.`, `Lee solo cabeceras y tamaños; excluye placeholders sin cargar pesos en RAM.`, `Una petición solo puede activar un recurso que sigue existiendo en este catálogo` to the rest of the system?**
  _126 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `agent_service.js` be split into smaller, more focused modules?**
  _Cohesion score 0.07272727272727272 - nodes in this community are weakly interconnected._
- **Should `NanoIcon` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `LocalRuntimeBridge` be split into smaller, more focused modules?**
  _Cohesion score 0.06095791001451379 - nodes in this community are weakly interconnected._