# A3 — SystemGraph + Capability Availability + System Intent Catalog

> Estado: IMPLEMENTADO · DEVICE-VERIFIED: NO

## Alcance

A3 transforma el substrate factual de A2 en un **modelo factual, tipado y
consultable del dispositivo**. NO es planner, executor, gestor de permisos ni
dump de contexto del LLM. No introduce CandidateAction (A5) ni razonamiento
autónomo.

```
SystemInventory (A2, read)
        ↓
SystemGraphBuilder (probes)
        ↓
SystemGraph (conocimiento)
```

## Modelos

- `SystemCapability` — taxonomía tipada (inventario, device actions,
  notificaciones, accesibilidad, destinos de sistema, Linux, futuras).
- `CapabilityAvailability` / `CapabilityAvailabilityKind` — estado explícito
  (available / unavailable / requiresUserEnablement / requiresAccessibility /
  requiresNotificationAccess / unsupported / unknown). No bool.
- `SystemEvidence` / `SystemEvidenceSource` — proveniencia de cada afirmación.
- `SystemRole` / `SystemRoleBinding` — solo `launcher` se resuelve en A3 (de
  `DeviceProfile.defaultLauncherPackage`).
- `SystemDestination` — destinos SEMÁNTICOS (no strings crudos de Intent).
- `SystemIntentCatalog` / `SystemDestinationMeta` — metadatos; solo NAVEGACIÓN.
- `SystemIntentLauncher` / `SystemIntentResult` — frontera de ejecución (ISP,
  separada de `SystemInventory`).
- `SystemGraph` / `SystemGraphBuilder` — snapshot compuesto.

## Fuentes de evidencia

`packageManager`, `deviceBuild`, `accessibilityService`, `notificationListener`,
`androidSdk`, `linuxRuntime`. NUNCA LLM/OCR/Vision/texto de pantalla como
evidencia autoritativa de capability.

## Estados de capability (A3)

- `readDeviceProfile`, `listLaunchableApps`, `launchApps` → available (A2).
- `globalBack/globalHome/globalRecents/openNotifications/openQuickSettings`,
  `observeAccessibility`, `interactAccessibility` → available o
  `requiresAccessibility` (estado real vía `devicePermissionStatus`).
- `readNotifications`, `replyNotifications` → available o
  `requiresNotificationAccess` (estado real vía `NotificationManagerCompat`).
- `openSystemSettings/openWifiSettings/openBluetoothSettings` → available
  (destinos oficiales allowlisted).
- `linuxExecution` → available/unavailable (distros registradas).
- `mediaProjection`, `developerAdb`, `shizuku`, `deviceOwner`, `root` →
  `unsupported` (sin backend en A3, nunca available).

## SystemDestination allowlist

`sender`, `wifi_settings`, `bluetooth_settings` — mapeados en la frontera nativa
a `Settings.ACTION_SETTINGS` / `ACTION_WIFI_SETTINGS` / `ACTION_BLUETOOTH_SETTINGS`.
Los destinos accessibility/notification listener/app details **NO se duplican**:
ya los abre `DevicePermissionsChannelHandler`.

## Frontera nativa

`AndroidSystemIntentExecutor` (allowlist) + método `openSystemDestination` en
`SystemInventoryChannelHandler` (main thread). El executor NO acepta strings
crudos de Intent, component names, URIs ni extras arbitrarios.

## Limitaciones

- Sólo `launcher` como role; sin heurística OEM.
- Sólo NAVEGACIÓN (no cambio de estado: `changeBluetoothState` no existe).
- Sin refresh automático (explícito).
- A2/A3 nativo sin validación de device.

## Integración futura (A5 Candidate-First)

El planner NO recibe intents ni packages crudos. A5/A6 derivará CandidateAction
del SystemGraph (pregunta "¿qué es posible?") sin acoplar conocimiento y
ejecución.

## Verificación

PROVEN BY UNIT TEST (domain + launcher fake). PROVEN BY BUILD (Kotlin).
IMPLEMENTED BUT NOT DEVICE-VERIFIED (ejecución de intents en device real).
