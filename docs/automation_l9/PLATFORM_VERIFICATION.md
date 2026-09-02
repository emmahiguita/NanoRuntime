# A14.5 — Verificación de Resultado por Plataforma

> Estado: FUNDACIÓN IMPLEMENTADA · verificación no-UI conectada en linux.write y
> force_stop_package. Sin nuevos privilegios.

## Principio central

```
EXECUTION SUCCESS  !=  ACTION VERIFIED  !=  GOAL SATISFIED
```

- `process.run()` devolvió OK  ≠  el comando logró su efecto.
- dispatch de reply  ≠  mensaje leído por el humano.
- forceStop devolvió  ≠  proceso necesariamente detenido.

El módulo ya tenía percepción, candidates, governance y ejecución. Faltaba que
Nano pudiera **demostrar** que una acción no-UI ocurrió. Este documento fija el
modelo que lo habilita.

## Predicados de plataforma (tipados, sealed)

`PlatformPredicate` subclases:

- `ForegroundPackageEquals(pkg)` — app en primer plano (launch_app).
- `PackageNotForeground(pkg)` — app ya no en primer plano (force_stop/back).
- `PackageProcessAbsent(pkg)` — proceso ausente (fuerza real; NO observable en
  Android moderno, se declara no-disponible).
- `ProcessExitCodeEquals(code)` — salida de un comando Linux.
- `FileExists(path)` — archivo existe (verificación de escritura).
- `FileContentContains(path, content)` — contenido/hash.
- `NotificationReplyAccepted(key)` — reply aceptado por RemoteInput.

Resultado (`PlatformPredicateResult`): `Satisfied(evidence)` /
`Unsatisfied(reason)` / `Unavailable(reason)`. Composición mínima: `evaluateAllOf`.

## Honestidad por dominio

| Dominio | Se verifica | Se declara no-observable |
|---------|-------------|--------------------------|
| App (launch) | primer plano | — |
| App (force-stop) | deja de estar en primer plano | proceso ausente (visibilidad restringida) |
| Linux (write) | archivo existe | — |
| Linux (run) | — (exit code en el executor) | re-observación del exit |
| Notificación (reply) | — | aceptación (solo RemoteInput) |
| Shizuku (query) | estado = observación factual | — |

## Arquitectura (SOLID, sin segundo verifier)

- `PlatformStateReader` (DIP) — lee hechos; `ActionVerifier` no depende de
  MethodChannel/Process/PackageManager/Shizuku.
- `PlatformVerificationRouter implements PlatformStateReader` — delega por
  dominio (app/Linux), no God object.
- `ActionVerifier` — evalua `platformPredicates` si están declarados; sin
  lector → `serviceUnavailable` (honesto, nunca éxito supuesto).
- `ActionExpectation` — añade `platformPredicates` (compatible; legacy UI fields
  intactos).

## Qué se conectó en producción

- `linux.writeFile` → verifica `FileExists(path)` → "escrito y verificado".
- `force_stop_package` → verifica `PackageNotForeground(pkg)` → "detenida
  (verificado)" vs "solicitada, no verificable".
- Si el lector no está / no es observable → se reporta "solo aceptado", NUNCA
  éxito.

## Memoria / sonido

Solo la verificación de plataforma positiva entrena memoria/flows. Una acción
"aceptada pero no verificada" NO genera aprendizaje positivo.

## Limitaciones conocidas

- Visibilidad de procesos Android restringida → `PackageProcessAbsent` no
  observable (documentado, no inventado).
- `NotificationReplyAccepted` / `ProcessExitCodeEquals`: la verificación vive en
  el executor (que posee el resultado estructurado); el lector no los re-observa.
- `launch_app` mantiene verificación UI (expectedPackage), no se duplicó con
  `ForegroundPackageEquals` para evitar falso negativo por settle.

## Próximo paso (no iniciado en esta fase)

1. Conectar `ForegroundPackageEquals` en `InstalledAppCandidateProvider` con
   sondeo de settle (evitar el falso negativo inicial).
2. Candidatos de Shizuku/linux que adjunten predicados al plan (flujo
   CandidateAction → ToolCall → verifier con preservación).
3. Verificación semántica de objetivos (switch real, no solo texto).
