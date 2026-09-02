# A14.5.4 — Verificación Semántica de Estados

> Estado: infraestructura genérica `StatePredicate`/`GoalPredicate` integrada en
> `GoalVerifier`. La demo de YouTube es un primer consumidor, no un caso especial.

## Principio

```
"activa Bluetooth"
   NO: pantalla contiene "Bluetooth" → success  (falso positivo)
   SÍ: estado real switch == enabled → VERIFIED

"reproduce este video"
   tap Play → control aceptado / UI cambió
   Goal verification: MediaPlaybackState == playing
   SOLO entonces → COMPLETED
```

El veredicto se deriva del ESTADO real del sistema, no de la presencia de
texto ni del "backend OK".

## Predicados de estado semántico (genéricos)

Extendieron el `PlatformPredicate` sellado existente (A14.5), sin segundo
sistema de verdad:

- `MediaPlaybackStateEquals(playing)` — reproducción de medios activa/inactiva.
- `ToggleStateEquals(SystemToggle.bluetooth|wifi, enabled)` — conmutador real.
- `TextFieldContains(text)` — contenido real de un campo (snapshot).
- `ConversationOpenEquals(package, conversationId)` — conversación abierta.
- (ya existentes) `ForegroundPackageEquals`, `FileExists`, `PackageProcessAbsent`,
  `NotificationReplyAccepted`, `ProcessExitCodeEquals`.

## Lectura factual (nativo pasivo)

`DevicePermissionsChannelHandler.systemState()`:
- media `AudioManager.isMusicActive` (deprecated pero funcional).
- Bluetooth `BluetoothAdapter.isEnabled` (requiere permiso API 31+ → try/catch
  devuelve false si no observable, honesto).
- WiFi `WifiManager.isWifiEnabled`.

`TextFieldContains` se resuelve contra el snapshot de accesibilidad (nodo de
texto real). Sin snapshot → no-observable, nunca asumido.

## Integración

- `PlatformVerificationRouter` evalúa los predicados semánticos (fuente
  `systemStateSource` inyectada).
- `GoalVerifier` recibe `stateReader` y `GoalExpectation.statePredicates`:
  - `Unsatisfied` → `notSatisfied` (estado real no coincide).
  - `Unavailable` → `unverified` (no observable, nunca éxito).
  - `Satisfied` → objetivo cumplido.

Distinción mantenida:
```
EXECUTE → ACTION VERIFY (postcondición de plataforma) → GOAL VERIFY (estado semántico) → MEMORY
```

## Cómo se usa

- `deterministic_catalog` / `app_launch_resolver` ya declaran `GoalExpectation`;
  ahora pueden añadir `statePredicates` para exigir el estado real (p.ej.
  `ToggleStateEquals(bluetooth, true)` en "activa Bluetooth").
- La demo de YouTube: `MediaPlaybackStateEquals(playing=true)` cierra
  "reproduce este video" con evidencia real de audio, no solo "abrí el player".

## Limitaciones

- `isMusicActive`/`isWifiEnabled` están deprecated; siguen funcionales en API
  36 (documentado). Si dejan de reportar, el predicado cae a `unverified`, no a
  falso positivo.
- `ConversationOpenEquals`: el id exacto de conversación no es observable de
  forma fiable; se resuelve como `ForegroundPackageEquals(package)`.
- La entrega/lectura de un reply sigue NO asumible (`NotificationReplyAccepted`
  = aceptado por RemoteInput, no entregado).
