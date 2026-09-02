# A14.3 — Shizuku Availability (factual, no ejecución)

> Estado: DOMAIN COMPLETE · NATIVE BACKEND READY (dependencia rikka integrada) ·
> NO PRIVILEGED EXECUTION.

## Propósito

Detección FACTUAL de disponibilidad de Shizuku, separada de autorización y de
ejecución. Responde: ¿compilado? ¿instalado? ¿binder vivo? ¿Nano autorizado?
NO ejecuta shell, NO acciones privilegiadas, NO pide permiso automáticamente.

## Modelo de estado

`ShizukuStatus { unsupported, notInstalled, serviceUnavailable,
permissionRequired, available }` + `ShizukuAvailability { status, reason }`.
Disponibilidad != autorización != acción autorizada != segura != ejecutada.

## Provider

`ShizukuAvailabilityProvider.status()` (DIP, dominio sin rikka/Binder/MethodChannel).

Producción usa `MethodChannelShizukuAvailabilityProvider`: consulta el canal
nativo `com.nanoai/device_permissions` → `queryShizukuStatus` y mapea los
hechos a `ShizukuStatus`. Si el canal no responde (tests/desktop/runtime sin
nativo) devuelve `unsupported` — nunca finge `available`.

Mapeo real:
- `installed=false` → `notInstalled`
- `installed && !binderAlive` → `serviceUnavailable`
- `installed && binderAlive && !granted` → `permissionRequired`
- `installed && binderAlive && granted` → `available`

El default `UnsupportedShizukuAvailabilityProvider` (→ `unsupported`) se
mantiene solo como fallback/test; NO se inyecta en producción.

## Native backend

- Dependencia: `dev.rikka.shizuku:api:13.1.5` (oficial, Apache-2.0,
  minSdk 23 <= nuestro minSdk 26). Artefacto: github.com/rikkaapps/shizuku.
- Manifest: `<provider rikka.shizuku.ShizukuProvider>`, permiso
  `moe.shizuku.manager.permission.API_V23` y `<meta-data moe.shizuku.client.V3_SUPPORT>`.
- ProGuard: `-keep class rikka.shizuku.**` + `-dontwarn` (R8 binding dinámico).
- `DevicePermissionsChannelHandler.queryShizukuStatus()`: SOLO consultas pasivas
  (`Shizuku.pingBinder`, `Shizuku.checkSelfPermission`, PackageManager). No abre
  diálogos, no ejecuta comandos, no manipula PackageManager.

## SystemGraph

`ShizukuCapabilityProbe` (nuevo, patrón A3 sin reescribir builder) traduce la
disponibilidad a `SystemCapability.shizuku` con `CapabilityAvailabilityKind`:
`available` / `requiresUserEnablement` (permissionRequired) / `unavailable`
(notInstalled, serviceUnavailable, unsupported). Cableado en
`systemGraphBuilderProvider.probes`.

## Wire (planner productivo)

`CandidateFirstPlanner` recibe `shizukuSource` opcional (inyectado solo en
producción) y lo pasa a `ActionGovernance.govern(..., shizuku:)`. El broker
resuelve tier `shizuku` usando la disponibilidad real; ausente → unavailable
(conservador).

## PrivilegeBroker

`resolve(..., shizuku: ShizukuAvailability?)` → tier `shizuku` consume la
disponibilidad real. null → unavailable (conservador). `available` → broker
reporta privilegio técnico disponible, PERO governance (firewall/critic) sigue
obligatorio. `capability != authority`.

## Security

- Sin shell (`executeShell`/`runCommand`/`shizukuShell`) en producción.
- Sin CandidateProvider Shizuku (A14.4).
- Sin tools en ToolRegistry (disponibilidad no es tool ejecutable).
- Sin visibilidad al LLM.
- `queryShizukuStatus` es pasivo: nunca abre diálogo de permiso ni ejecuta una
  acción. La solicitud de permiso (futura) queda separada y acoplada solo a
  acción de usuario explícita.

## Volumen de pruebas

No se añadieron tests automáticos en A14.3 (validación manual en device, por
decisión del maintainer). La suite existente cubre el contrato (broker/mcp) y
continúa pasando sin cambios.

## Device verification (CPH2557, Android 15)

`flutter build apk --debug` + `--release` OK (dependencia + R8). APK instalado.
Escenarios a validar manualmente:

- A. Shizuku no instalado/parado → `notInstalled` / `serviceUnavailable`.
- B. Shizuku corriendo, Nano no autorizado → `permissionRequired`.
- C. Shizuku corriendo + Nano autorizado → `available`.

## A14.4 seam

La primera acción Shizuku tipada (UNA operación de bajo riesgo, reversible) se
implementará solo tras validar disponibilidad en device, pasando por
CandidateAction → IntentFirewall → Critic → PrivilegeBroker → Policy →
ShizukuExecutor → Verifier. Nunca se expone shell genérico.
