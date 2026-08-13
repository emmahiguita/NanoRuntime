# Informe — Visor VNC: animación de carga, handshake, tiempo de carga y compatibilidad

Fecha: 2026-08-12 (tarde)
Dispositivo: Oppo CPH2557 / ColorOS (`VGL7MVFMDYQG8T55`), app `dev.nanoai.mobile`
Método: análisis en vivo — `adb logcat` a tiempo real + captura de bytes del socket RFB 5901 + inspección de procesos `/proc` + lectura directa del código.
Alcance pedido: corregir el tiempo de carga y la animación que no llega a cargar en el visor (handshake), compatibilidad, y llegar al escritorio Linux en el visor. **Sin programar: solo diagnóstico y plan.**

---

## 1. Resumen ejecutivo

**El escritorio Linux está completamente vivo y funcionando.** Xvnc escucha en `127.0.0.1:5901`, openbox/tint2/aterm están en ejecución, y el handshake RFB 3.8 se completa correctamente en cada conexión. El fallo es 100% del visor Flutter, en el parser RFB, y es **un solo bug de corrupción de buffer** que se reproduce en el 100% de los intentos.

| Dimensión | Estado |
|---|---|
| Escritorio Linux (Xvnc) | **VIVO y sano** — PID 25665, display `:1`, `-SecurityTypes None`, geometría 1280x720 depth 24 |
| openbox / tint2 / aterm | **VIVOS** — PID 25671 / 25676 / 25694 |
| Puerto 5901 | **LISTEN** (`/proc/net/tcp` state 0A, uid 10345) |
| Handshake RFB 3.8 | **OK siempre** (`Server: RFB 003.008` → `Framebuffer: 1280x720, depth=24`) |
| Primer framebuffer (3.7 MB) | **CORROMPIDO por el visor** → desincronización → desconexión → bucle |
| Animación de carga | **Nunca resuelve**: el spinner se muestra entre reconexiones y el escritorio jamás se pinta |
| Compatibilidad RFB | **Correcta**: RFB 3.3 legacy y 3.8 soportados; pixel format coincide con el nativo del servidor; el FBU llega en 18 rects y el parser los maneja bien |

**Veredicto:** no hay que tocar nada del lado nativo (Kotlin/C/Xvnc/rootfs). Un único fix de una línea y media en `lib/features/desktop/vnc_client.dart` resuelve el síntoma completo. Todo lo demás (orquestación, handshake, pixel format, banding de rects) ya funciona y **no debe modificarse**.

---

## 2. Evidencia en vivo

### 2.1 Procesos reales en el dispositivo

```
PID 25665 : /system/bin/linker64 .../usr/bin/Xvnc :1 -geometry 1280x720 -depth 24 -rfbport 5901 -SecurityTypes None -localhost yes -listen tcp
PID 25671 : /system/bin/linker64 .../usr/bin/openbox
PID 25676 : /system/bin/linker64 .../usr/bin/tint2
PID 25694 : /system/bin/linker64 .../usr/bin/aterm -bg #0d1117 -fg #00ff9d
```

El puerto 5901 está en LISTEN y el dueño es el uid de la app. No hay huérfanos ni zombies visibles en este ciclo.

### 2.2 Logcat a tiempo real (tag `flutter`, PID 25253)

El bucle se reproduce sin variación, cada ~6 s:

```
17:15:39.509 [vnc] Conectando a 127.0.0.1:5901...
17:15:39.517 [vnc] Server: RFB 003.008
17:15:39.525 [vnc] Framebuffer: 1280x720, depth=24, "u0_a345@localhost"
17:15:39.674 [vnc] Unknown msg type: 24          ← desincronización (a veces)
...
17:15:33.437 [vnc] Framebuffer: 1280x720, depth=24
17:15:33.540 [vnc] Encoding no soportado: 39173 (rect 21761/26117 0,0 0x0)  ← desincronización (a veces)
```

Dos errores alternantes, ambos con el mismo origen:

- `Unknown msg type: 24` → el parser leyó `0x18` (gris del escritorio Openbox) como tipo de mensaje.
- `Encoding no soportado: 39173 (rect 21761/26117 0,0 0x0)` → el parser leyó bytes de píxeles (`0x9905`, `0x5501`, `0x6605`) como cabecera de rect. `numRects=26117` es absurdo: el server manda **18** rects (verificado con captura directa).

Ambos significan lo mismo: **el parser está leyendo datos de píxeles como si fueran cabeceras de protocolo**, es decir, el stream se desincronizó justo después del ServerInit.

### 2.3 Captura directa del socket (cliente RFB mínimo, handshake correcto)

Para descartar que el servidor enviara mensajes "raros", se conectó un cliente de referencia al mismo puerto 5901 vía `adb forward`. Resultado:

```
[version]    RFB 003.008
[security]   count=1 types=01        (None)
[secresult]  00000000
[serverinit] 1280x720 depth=24 bpp=32 name="u0_a345@localhost"
[next]       first byte (msg type) = 0 (FramebufferUpdate)
[next]       FramebufferUpdate numRects=18
```

El servidor envía **exactamente** lo esperado: FBU con 18 rects Raw. **No existe ningún "msg type 24" legítimo.** El `msg type 24` y el `encoding 39173` son artefactos de la corrupción del buffer del visor.

---

## 3. Bug primario (P0, CONFIRMADO) — corrupción del buffer de recepción

### Ficha

```
Archivo:         lib/features/desktop/vnc_client.dart
Función:         _onData(Uint8List data)
Líneas:          233-245 (bloque de crecimiento del buffer)
Problema:        Al crecer el buffer, se hace _readPos = 0 SIN actualizar _end.
                 El getter _availableBytes (= _end - _readPos) pasa a devolver
                 el _end viejo en lugar de los bytes realmente disponibles.
Evidencia:       - Código: línea 242 `_readPos = 0;` sin `_end = ...`.
                 - Runtime: "Unknown msg type: 24" y "Encoding 39173" (bytes de
                   píxeles leídos como cabecera), 100% reproducible.
                 - Captura de socket: el server manda FBU numRects=18 limpio.
Causa raíz:      _end no se re-sincroniza tras compactar el buffer en el bloque
                 de crecimiento. El bloque de COMPACTACIÓN (líneas 222-229) sí
                 lo hace (`_end = newLen`); el de CRECIMIENTO no.
Impacto:         - Se inserta un hueco de _readPos bytes 0x00 en el stream.
                 - Se pierden los últimos _readPos bytes del chunk entrante.
                 - El parser se desincroniza → disconnect → reconexión en bucle.
                 - El escritorio nunca se pinta: solo spinner/retry.
Cómo reproducir: Abrir el visor VNC con el escritorio ya arrancado. Se dispara
                 SIEMPRE en el primer framebuffer (3.7 MB), porque el primer
                 crecimiento del buffer ocurre con _readPos=59 > 0.
Riesgo del cambio: NULO sobre el resto. Es un fix localizado en una función.
```

### Análisis exacto

Tras el handshake, `_readPos` vale 59 (12 versión + 2 security + 4 result + 41 ServerInit). El primer chunk del framebuffer (3.7 MB) hace `needed > _rawBuf.length - _readPos`, entra al bloque de crecimiento y:

```dart
final needed = _availableBytes + data.length;      // correcto
if (needed > _rawBuf.length - _readPos) {
  var cap = _rawBuf.isEmpty ? 64 * 1024 : _rawBuf.length;
  while (cap - _readPos < needed) cap *= 2;
  final newBuf = Uint8List(cap);
  newBuf.setRange(0, _availableBytes, _rawBuf, _readPos); // copia lo válido
  _rawBuf = newBuf;
  _readPos = 0;                                    // ← BUG: _end NO se actualiza
}
_rawBuf.setRange(_readPos + _availableBytes, _readPos + needed, data); // ← usa _availableBytes STALE
_end = _readPos + needed;
```

En la línea final, `_availableBytes` es el getter `_end - _readPos`. Con `_readPos = 0` y `_end` todavía apuntando al valor viejo (`59` en el primer FBU), el getter devuelve `59` en vez de `0`. Consecuencia:

1. `setRange(59, 65536, data)` escribe el chunk **desplazado 59 bytes**, dejando 59 bytes `0x00` de hueco y descartando los últimos 59 bytes del chunk.
2. `_end = 65536` marca el hueco como "datos válidos".

A partir de ahí el parser consume 59 bytes `0x00` como mensajes fantasma y luego bytes de píxel reales como cabeceras: de ahí `Unknown msg type: 24` (byte de píxel `0x18`) y `Encoding 39173` (`0x9905`).

### Fix mínimo (descrito, NO aplicado — pendiente de aprobación)

Capturar los bytes disponibles **antes** de resetear `_readPos` y re-sincronizar `_end`:

```dart
final needed = _availableBytes + data.length;
if (needed > _rawBuf.length - _readPos) {
  var cap = _rawBuf.isEmpty ? 64 * 1024 : _rawBuf.length;
  while (cap - _readPos < needed) cap *= 2;
  final avail = _availableBytes;                 // capturar ANTES del reset
  final newBuf = Uint8List(cap);
  newBuf.setRange(0, avail, _rawBuf, _readPos);
  _rawBuf = newBuf;
  _readPos = 0;
  _end = avail;                                  // re-sincronizar _end
}
_rawBuf.setRange(_readPos + _availableBytes, _readPos + needed, data);
_end = _readPos + needed;
```

Con esto `_availableBytes` vuelve a ser consistente tras el reset y el stream queda intacto.

---

## 4. Cadena de fallo (diagrama)

```
VncScreen._connect()
  └─ VncClient.connect() ── TCP 127.0.0.1:5901 ──► Xvnc (vivo, sano)
  └─ Handshake RFB 3.8 OK (16 ms): "Server RFB 003.008" → ServerInit correcto
  └─ Primer FBU (3.7 MB, 18 rects) llega en chunks
        └─ _onData() crece el buffer con _readPos=59
             └─ [P0] _end no se actualiza → hueco de 59 bytes + pérdida de 59 bytes
                  └─ parser desincronizado
                       ├─ "Unknown msg type: 24"  (byte de píxel 0x18)
                       └─ "Encoding no soportado: 39173" (bytes 0x9905)
                            └─ disconnect()
                                 └─ onDisconnected → _scheduleReconnect()
                                      └─ bucle de reconexión ~6 s
                                           └─ UI: spinner / botón "Reintentar" eternos
```

---

## 5. Por qué "la animación no llega a cargar"

`vnc_screen.dart` `_buildContent()` (líneas 456-553) decide qué pintar:

- `_busy && _frame == null` → `CircularProgressIndicator` (spinner).
- `!_connected || _frame == null` → icono + botón "Reintentar Conexión".
- Solo si `_frame != null` → `RawImage` con el framebuffer.

Como el parser nunca llega a entregar un frame válido (`onFrame` nunca se llama con una imagen del escritorio), `_frame` permanece `null` para siempre. El usuario ve únicamente el spinner y el botón de reintento alternándose: la "animación que no carga". **No es un problema de la animación en sí** (es un `CircularProgressIndicator` trivial); es que el estado `connected`+`frame` nunca se alcanza por el bug del buffer.

El cronómetro y la barra de etapas de `desktop_launch_screen.dart` (`_applyDesktopStatus`, líneas 104-178) sí funcionan correctamente y reflejan las etapas reales del backend (idle→starting→xvnc→rfb→wm→ready). No requieren cambios.

---

## 6. Hallazgos secundarios (orden de prioridad)

### P1 — Decode del frame en el hilo de UI (`_emitFrame`, vnc_client.dart 654-693)

`decodeImageFromPixels` de 3.7 MB RGBA se ejecuta en el isolate de UI con un `timeout` de 5 s. Es la causa del jank visible en el primer frame y del síntoma histórico VNC-9 ("decode hung"). No rompe la proyección pero degrada el tiempo de carga percibido. **Opcional:** decodificar en un `Isolate.run` y devolver el `ui.Image` por callback (cuidando que `dart:ui` en isolate requiere `rootBundle`/`ImageDescriptor` según versión). No es bloqueante para el fix del visor.

### P2 — `BLASTBufferQueue: Can't acquire next buffer` (torrente en logcat)

`[SurfaceView[dev.nanoai.mobile/...MainActivity]#1] acquireNextBufferLocked: Already acquired max frames 4`. Es la superficie de render de Flutter. Aparece porque el isolate de UI está saturado por el bucle reconexión + decodes fallidos. **Es síntoma, no causa**: desaparece al corregir P0. No tocar.

### P3 — Intervalo de reconexión ~6 s no coincide con el backoff documentado

`vnc_screen.dart` `_scheduleReconnect()` (líneas 83-112) documenta backoff exponencial 1→2→4→8→16→30→30. El log muestra **~5.97 s constantes**, no potencias de 2. El log tampoco muestra `Socket error` ni `Conexión cerrada por el servidor`, lo que sugiere que `onDisconnected` se dispara por una vía distinta a `_onError`/`_onDone` (probablemente el `onDone` del socket tras `destroy()`, o disparos múltiples por ciclo). **REQUIERE PRUEBA DINÁMICA**: no es bloqueante, pero conviene verificarlo tras el fix de P0 para confirmar que el backoff quedó correcto.

### P4 — Parser frágil ante msg types desconocidos (vnc_client.dart 412-415 y 500-507)

El `default` del switch hace `disconnect()` duro ante cualquier byte no reconocido. Con el buffer corregido no aparecen msg types desconocidos en este server (verificado con captura: solo FBU=0), pero un mensaje de extensión legítimo futuro (p. ej. EndOfContinuousUpdates=150 de TigerVNC, o ServerCutText con clipboard) rompería la sesión. **Recomendación de robustez** (no para este fix): consumir mensajes desconocidos saltando su payload si el protocolo lo define, o al menos loguear sin `disconnect()`.

### P5 — Disposal del frame anterior (ya resuelto en código)

`vnc_screen.dart` 142-159 ya hace `addPostFrameCallback((_) => prev.dispose())`. Correcto. No tocar.

---

## 7. Compatibilidad (matriz verificada)

| Elemento | Estado | Evidencia |
|---|---|---|
| RFB 3.8 (handshake estándar) | **COMPATIBLE** | `Server: RFB 003.008` + ServerInit correcto en cada conexión |
| RFB 3.3 legacy (TigerVNC `-SecurityTypes None`) | **COMPATIBLE** (defensa) | `_legacy33` implementado (fix VNC-8); en runtime actual el server ofrece 3.8 |
| Pixel format | **COINCIDE** (sin conversión) | Server nativo: bpp32/depth24/little-endian/truecolor, shifts 16/8/0. Cliente pide exactamente lo mismo. `_applyRawRect` hace BGR→RGBA correcto |
| Encoding Raw (0) y CopyRect (1) | **COMPATIBLE** | `_sendSetEncodings` negocia Raw+CopyRect; el server responde Raw |
| FBU inicial en 18 rects (banding) | **SOPORTADO** | El FSM incremental `_rectsTotal/_rectActive` maneja N rects; captura confirma numRects=18 |
| `-localhost yes` / listen tcp | **COMPATIBLE** | Xvnc escucha 127.0.0.1:5901, el visor conecta a loopback |
| xkbcomp / XKB | **RESUELTO (no regresión)** | wrapper + shim desplegados; Xvnc vivo y estable >20 min |
| Anti-brute-force TigerVNC | **VIGILAR** | El backend ya NO probea TCP (usa `/proc/<pid>/stat`), evitando "security failures". Mantener así |

No hay desajuste de versión SDK/Gradle/NDK implicado en este síntoma: el fallo es puramente Dart.

---

## 8. Lo que YA funciona y NO debe tocarse

1. Orquestación del arranque: `DesktopController` → `DesktopSessionManager` → `InternalXvncBackend` (Xvnc + openbox + tint2 + aterm todos vivos).
2. Handshake RFB 3.8 y el camino legacy 3.3 (fix VNC-8).
3. `_sendSetPixelFormat` / `_sendSetEncodings` / `_requestUpdate` (bytes correctos).
4. FSM incremental del FramebufferUpdate (maneja 18 rects correctamente).
5. Backpressure `_updatePending` y heartbeat (30 s) / frame-timeout (60 s).
6. Gestos táctiles (`onPanEnd`/`onPanCancel` ya presentes, fix VNC-3 aplicado).
7. Disposal del frame viejo (fix VNC-4/leak aplicado).
8. Pantalla de lanzamiento con cronómetro y etapas reales.

---

## 9. Tabla maestra

| ID | Prio | Archivo | Componente | Error | Evidencia | Causa raíz | Impacto | Solución |
|---|---|---|---|---|---|---|---|---|
| VNC-BUF-1 | **P0** | vnc_client.dart:233-245 | Buffer recepción RFB | `_readPos=0` sin actualizar `_end` → hueco + pérdida de bytes | "Unknown msg type: 24" / "Encoding 39173" 100% repro; captura de socket muestra FBU limpio numRects=18 | `_end` no re-sincronizado en el bloque de crecimiento | Escritorio jamás se pinta; bucle de reconexión | Capturar `avail` antes del reset y asignar `_end=avail` |
| VNC-DEC-1 | P1 | vnc_client.dart:654-693 | Decode | `decodeImageFromPixels` 3.7 MB en isolate UI | Jank en primer frame; histórico VNC-9 | Decode síncrono en hilo de UI | Tiempo de carga percibido alto | (Opcional) decode en isolate aislado |
| VNC-REC-1 | P3 | vnc_screen.dart:83-112 | Reconexión | Intervalo real ~5.97 s ≠ backoff 1/2/4/8 | Logcat: gaps constantes ~6 s | Vía de disparo de `onDisconnected` no confirmada | UX de reconexión impredecible | PRUEBA DINÁMICA tras P0 |
| VNC-MSG-1 | P4 | vnc_client.dart:412-415,500-507 | Parser | `disconnect()` duro ante msg/encoding desconocido | Lectura de código | Parser no tolerante | Frágil ante extensiones RFB futuras | Manejo defensivo (no urgente) |
| VNC-SURF-1 | P2 | — | Render | `BLASTBufferQueue` max frames | Torrente en logcat | UI isolate saturado por el bucle | Backpressure de render | Se resuelve con P0 (síntoma) |

---

## 10. Plan de corrección (solo descripción; nada aplicado)

### FASE 0 — Verificación de que el escritorio sigue sano (sin cambios)
Confirmar antes de tocar nada: `Xvnc/openbox/tint2/aterm` vivos y 5901 en LISTEN. Criterio de salida: los 4 procesos siguen vivos. (Ya verificado en este informe.)

### FASE 1 — Fix único de P0 (VNC-BUF-1)
Archivo: `lib/features/desktop/vnc_client.dart`, función `_onData`. Cambio descrito en §3. Prohibido tocar cualquier otra función en este paso. Riesgo: nulo fuera del parser.

### FASE 2 — Regresión del visor
1. Reinstalar APK y abrir el visor con el escritorio arrancado.
2. Criterio de salida: `[vnc] Framebuffer: 1280x720` seguido de **frame visible** (sin `Unknown msg type` ni `Encoding no soportado`), y el escritorio Openbox proyectado con cursor.
3. Verificar interacción: tap, drag (suelta el botón), teclado.
4. Verificar reconexión: matar Xvnc y confirmar que el visor reconecta y vuelve a pintar.
5. Confirmar que el torrente `BLASTBufferQueue` desaparece.

### FASE 3 — Opcional: decode fuera del UI isolate (VNC-DEC-1) y robustez del parser (VNC-MSG-1)
Solo tras FASE 2 en verde, y solo si el tiempo de carga del primer frame sigue siendo percibido como alto.

---

## 11. Criterios de cierre

- P0 corregido: `Unknown msg type: 24` y `Encoding no soportado` dejan de aparecer (0 ocurrencias en 60 s de visor activo).
- El escritorio Linux se proyecta en el visor sin spinner infinito.
- Sin regresiones en terminal, paquetes (apt/dpkg) ni en el arranque del escritorio.
- Los procesos nativos (Xvnc/openbox/tint2/aterm) no se ven afectados por el cambio (el fix es Dart puro, no toca el lado nativo).
