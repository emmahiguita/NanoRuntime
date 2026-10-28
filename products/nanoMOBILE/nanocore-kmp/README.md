# nanocore-kmp

Módulo **Kotlin Multiplatform** compartido entre **Android** e **iOS** para NanoAI.

## Arquitectura

```
nanocore-kmp/
└── src/
    ├── commonMain/        ← Lógica pura (100 % Kotlin stdlib + coroutines)
    │   ├── agent/
    │   │   ├── AgentLedger.kt          Memoria operativa podada (port de NanoTranscriptLedger.dart)
    │   │   ├── SensitiveDataPolicy.kt  Detección y redacción de datos sensibles
    │   │   └── TargetMatchPolicy.kt    Política de coincidencia de nodos UI
    │   ├── inference/
    │   │   ├── ThermalPolicy.kt        Throttling térmico normalizado
    │   │   ├── ModelGate.kt            Barrera de propiedad del motor (port de LocalModelGate.kt)
    │   │   └── InferenceEngine.kt      `expect class` del motor local
    │   └── messaging/
    │       ├── MessageClassifier.kt    Clasificador de notificaciones (port de WhatsAppClassifier.kt)
    │       ├── ReplyIdempotencyGuard.kt Guard at-most-once (port de ReplyAttemptLedger.kt)
    │       └── PlatformUrlOpener.kt    `expect object` para abrir URLs
    │
    ├── androidMain/       ← `actual` que envuelven el código Android existente
    │   ├── inference/
    │   │   ├── PlatformThermalProvider.kt  → PowerManager
    │   │   └── InferenceEngine.kt          → LiteRtEngineOwner / MNN JNI
    │   └── messaging/
    │       ├── PlatformHashProvider.kt     → MessageDigest SHA-256
    │       ├── NotificationBridge.kt       → StatusBarNotification → MessageEvidence
    │       └── PlatformUrlOpener.kt        → Intent.ACTION_VIEW
    │
    ├── iosMain/           ← `actual` con APIs de Apple (sin sandbox)
    │   ├── inference/
    │   │   ├── PlatformThermalProvider.kt  → NSProcessInfo.thermalState
    │   │   └── InferenceEngine.kt          → llama.cpp / Metal / CoreML
    │   └── messaging/
    │       ├── PlatformHashProvider.kt     → CommonCrypto CC_SHA256
    │       ├── IosNotificationBridge.kt    → UNNotification + WhatsApp URL Scheme
    │       └── (PlatformUrlOpener actual en IosNotificationBridge.kt)
    │
    ├── commonTest/        ← Tests unitarios sin emulador (todas las plataformas)
    │   └── NanoCoreTests.kt
    │
    └── nativeInterop/
        └── cinterop/
            └── llama.def  ← Descriptor cinterop para llama.cpp + Metal
```

## Lo que comparte vs lo que difiere

| Componente | commonMain | androidMain | iosMain |
|---|---|---|---|
| `ThermalPolicy` (reglas) | ✅ | — | — |
| `PlatformThermalProvider` | `expect` | `PowerManager` | `NSProcessInfo` |
| `ModelGate` (mutex) | ✅ | — | — |
| `InferenceEngine` (contrato) | `expect` | LiteRT / MNN JNI | llama.cpp Metal |
| `AgentLedger` | ✅ | — | — |
| `SensitiveDataPolicy` | ✅ | — | — |
| `TargetMatchPolicy` | ✅ | — | — |
| `MessageClassifier` (reglas) | ✅ | — | — |
| Fuente de notificaciones | — | `NotificationListenerService` | Share Extension / UNNotification |
| Envío de respuesta | — | `RemoteInput` | `whatsapp://` URL Scheme |

## Integración con Flutter

El módulo se consume desde el flutter_app de cada plataforma vía `MethodChannel`:

```
Flutter (Dart) ←MethodChannel→ nanocore-kmp (commonMain)
                                     ↓
                              androidMain / iosMain actual
```

## TODOs pendientes para iOS

1. **cinterop llama.cpp** — compilar llama.cpp con `-DGGML_METAL=ON` para arm64 y
   conectar `NativeLlamaBridge` con los símbolos reales de `llama.h`.
2. **cinterop CommonCrypto** — `CryptoKitBridge.sha256Hex()` con `CC_SHA256`.
3. **Share Extension** — target Xcode separado que alimenta `IosNotificationBridge`.
4. **App Intents / Siri Shortcuts** — definir `AppIntent` para las acciones del agente.
5. **Añadir target `ios/`** en flutter_app — `flutter create --platforms=ios .`
