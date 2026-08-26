# A14.3 — Shizuku Availability (factual, no ejecución)

> Estado: DOMAIN COMPLETE · BACKEND NOT DEVICE-READY (sin dependencia rikka) ·
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
`UnsupportedShizukuAvailabilityProvider` default → `unsupported` (no finge).

## PrivilegeBroker

`resolve(..., shizuku: ShizukuAvailability?)` → tier `shizuku` consume la
disponibilidad real. null → unavailable (conservador). `available` → broker
reporta privilegio técnico disponible, PERO governance (firewall/critic) sigue
obligatorio.

## Security

- Sin shell (`executeShell`/`runCommand`/`shizukuShell`) en producción.
- Sin CandidateProvider Shizuku (A14.4).
- Sin tools en ToolRegistry (disponibilidad no es tool ejecutable).
- Sin visibilidad al LLM.
- `capability != authority`: Shizuku available + IntentSpec navigate +
  installPackage → firewall DENY (test).

## Backend

Dependencia rikka NO integrada (minSdk 26/targetSdk 36 sin impacto). El seam
nativo (`ShizukuAvailabilityService.kt`) es futuro. Device-verification pendiente.

## A14.4 seam

La primera acción Shizuku tipada (UNA operación de bajo riesgo, reversible) se
implementará solo tras validar disponibilidad en device.
