# Nano: Plataforma de Inteligencia Artificial Edge-First On-Device

**Nano** es una plataforma integral de IA local diseñada para ejecutarse de forma 100% privada, autónoma y sin dependencia de la nube directamente en dispositivos móviles y de recursos limitados.

El ecosistema se compone de dos núcleos interconectados:
1. **NanoRuntime**: Motor de inferencia LLM edge-first de ultra-baja memoria escrito en Rust puro, con degradación elegante, OOM-guard y streaming directo.
2. **NanoMobile (`nanoMOBILE`)**: Plataforma mobile en Flutter + Android nativo (Kotlin/C++) que otorga **ojos y manos reales** a los agentes mediante accesibilidad atómica, herramientas MCP estandarizadas, orquestación de mensajería y entorno Linux local.

---

## 1. Mapa de Arquitectura General

```mermaid
graph TD
    subgraph UI_Mobile ["Capa de Interfaz Mobile (Flutter / Dart)"]
        UI["Dashboard & Chat UI"]
        Browser["Navegador Web Integrado"]
        Term["Terminal Linux & Visor VNC"]
    end

    subgraph Agent_Core ["Motor de Automatización Móvil Nano"]
        MCP["MobileAutomationMcpClient (Protocolo MCP)"]
        Catalog["Catálogo Formal de Tools (8 Herramientas)"]
        Locator["NanoCompositeLocator (Dynamic-First)"]
        Gestures["MobileGestureExecutor (tap, type, swipe, key)"]
        Verifier["ActionVerifier (EXECUTED ≠ VERIFIED)"]
        Ledger["NanoTranscriptLedger (Memoria Operativa Podada)"]
        Gov["NanoSensitiveDataPolicy (Privacidad & Redacción)"]
    end

    subgraph Android_Native ["Capa Nativa Android (Kotlin / JNI)"]
        A11y["AgentAccessibilityService (MotionEventInjector)"]
        Snap["NanoAtomicSnapshotter (Snapshot Atómico)"]
        Notif["NotificationAutomationService (FGS dataSync)"]
        Shell["NanoshellWorker (Fork & PTY Linux)"]
    end

    subgraph Runtime_Inference ["Motor de Inferencia (NanoRuntime en Rust)"]
        Core["nanortime-core (Planificador, Memoria, OOM Guard)"]
        FFI["nanortime-ffi (Bindings llama.cpp / GGUF)"]
        Model["Modelos GGUF Locales (Qwen, DeepSeek, Llama)"]
    end

    UI --> MCP
    MCP --> Catalog
    MCP --> Locator
    MCP --> Gestures
    Gestures --> Verifier
    Gestures --> Ledger
    Gestures --> Gov
    Gestures -.->|MethodChannel| A11y
    Locator -.->|Atómico| Snap
    UI --> Core
    Core --> FFI
    FFI --> Model
```

---

## 2. Flujo de Automatización Móvil: Garantía `EXECUTED ≠ VERIFIED`

Todo gesto físico sobre el dispositivo separa estrictamente el despacho de la comprobación observable de postcondición:

```mermaid
sequenceDiagram
    autonumber
    actor Agente as Agente LLM / Orquestador
    participant MCP as MobileAutomationMcpClient
    participant Loc as NanoCompositeLocator
    participant Exec as MobileGestureExecutor
    participant Nativo as Android OS (A11y Service)
    participant Verif as ActionVerifier
    participant Ledg as NanoTranscriptLedger

    Agente->>MCP: callTool("tap", target)
    MCP->>Loc: locate(target, preSnapshot)
    Loc-->>MCP: Coordenadas dinámicas (X, Y)
    MCP->>Exec: tap(coordinates)
    Exec->>Nativo: dispatchGesture(tapAt)
    Nativo-->>Exec: executionOk = true
    Note over Exec,Verif: EXECUTED NO IMPLICA VERIFIED
    Exec->>Verif: verify(postSnapshot vs expectation)
    alt Pantalla reaccionó y cambió de estado
        Verif-->>Exec: verificationOk = true
        Exec->>Ledg: recordStep(succeeded: true)
        Exec-->>Agente: McpOperationStatus.success
    else Pantalla no reaccionó / congelada
        Verif-->>Exec: verificationOk = false
        Exec->>Ledg: recordStep(succeeded: false)
        Exec-->>Agente: McpOperationStatus.failed
    end
```

---

## 3. Pipeline de Mensajería y Agente Personal (WhatsApp)

Automatización respetuosa de mensajería con delimitación estricta de ráfagas, deduplicación y preservación de tono:

```mermaid
flowchart LR
    A["Notificación Entrante (Android)"] --> B["NotificationListenerService"]
    B --> C["BurstTurnGate (Ventana 120s)"]
    C --> D{"¿Es Intención Rápida?"}
    D -- Sí --> E["Pragmatic FastPath (Determinista)"]
    D -- No --> F["Inferencia LLM (NanoRuntime)"]
    E --> G["Gobernanza & Redacción"]
    F --> G
    G --> H["Borrador Sugerido / Envío Aprobado"]
```

---

## 4. Características Principales

### A. Motor de Automatización Móvil 100% Nativo Nano
- **Captura Atómica de Jerarquía**: `NanoAtomicSnapshotter` en Kotlin congela el árbol y captura la imagen simultáneamente sin bloqueos de UI ni puertos expuestos.
- **Localización Dinámica (Dynamic-First)**: `NanoCompositeLocator` resuelve elementos por `resourceId`, texto semántico, proximidad relativa y OCR visual como fallback.
- **Gestos Adaptativos**: `AdaptiveSwipeCalculator` calcula vectores geométricos adaptándose al contenedor scrollable identificado (`RecyclerView`, `ScrollView`).
- **Gobernanza y Privacidad**: `NanoSensitiveDataPolicy` redacta contraseñas, OTPs y tokens antes de ingresar al ledger (`[REDACTADO: N caracteres]`).
- **Contratos MCP Seguros**: Herramientas mutantes declaran `readOnlyHint = false` e `idempotentHint = false`.

### B. Inferencia LLM Edge (NanoRuntime)
- **Graceful Degradation**: Reducción dinámica de ventana de contexto (8192 → 512 tokens) según presión de RAM.
- **OS-Level Memory Paging**: `madvise(DONTNEED)` por capa para varianza de RSS < 1 MB.
- **OOM Guard & Thermal Controller**: Protección activa contra el OOM Killer y reducción de carga sobre 42°C.
- **Entropy Routing**: Evaluación de confianza (`1 - H_norm`) para enrutamiento local vs asistido.

---

## 5. Mapa de Componentes del Repositorio

```text
Nanoai/
├── products/
│   ├── nanoRUNTIME/                 # Núcleo de inferencia en Rust
│   │   ├── nanortime-core/          # Orquestador, memoria, OOM guard, RAG
│   │   ├── nanortime-ffi/           # Puente FFI hacia llama.cpp / GGUF
│   │   └── nanortime-cli/           # CLI de desarrollo y testing
│   │
│   └── nanoMOBILE/                  # Plataforma móvil para Android
│       └── flutter_app/
│           ├── lib/features/
│           │   ├── automation/      # Motor de automatización, MCP y agentes
│           │   │   └── engine/
│           │   │       ├── mcp/     # Clientes, ejecutores y catálogo MCP
│           │   │       ├── perception/ # Locators, snapshots y selectores
│           │   │       ├── governance/ # Políticas de datos sensibles
│           │   │       └── memory/  # Transcript ledger podado
│           │   ├── browser/         # Navegador integrado con PiP
│           │   └── skills/          # Catálogo formal de habilidades
│           │
│           ├── android/             # Integración nativa Android (Kotlin)
│           │   └── app/src/main/
│           │       └── kotlin/dev/nanoai/mobile/
│           │           ├── services/ # AgentAccessibilityService, Snapshotter
│           │           └── channels/ # MethodChannels con Flutter
│           │
│           ├── test/                # 149+ pruebas unitarias y de regresión
│           └── integration_test/    # Pruebas reales en hardware físico
│
└── docs/                            # Arquitectura, especificaciones y ADRs
```

---

## 6. Verificación y Calidad

El proyecto se valida continuamente mediante análisis estático estricto y pruebas en hardware real:

- **Límite Estricto de Líneas**: Ningún archivo del subsistema de automatización supera las 300 líneas.
- **Análisis Dart**: `dart analyze lib/ test/` -> **0 advertencias, 0 errores**.
- **Compilación Kotlin**: `.\gradlew.bat :app:compileDebugKotlin` -> **BUILD SUCCESSFUL**.
- **Pruebas Automatizadas**: **149/149 pruebas exitosas** en suites de automatización y herramientas.
- **Validación en Dispositivo Físico**: Ejecutado y validado en hardware real (`CPH2557` - Android 15).

---

## 7. Licencia

Distribuido bajo la **Licencia MIT** (consulta [`LICENSE`](LICENSE)).  
Copyright © 2026 Emmanuel Higuita Gómez.
