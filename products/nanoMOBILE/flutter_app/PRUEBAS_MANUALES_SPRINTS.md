# Pruebas manuales pendientes — sprints de automatización

Validación física en dispositivo (Oppo) por el propietario. Cada prueba = una
fila marcada al pasar. Evidencia real: logcat `adb logcat -s flutter` +
`ps`/`run-as` cuando aplique. Instalar APK con `adb install -r` y **force-stop
previo** del proceso viejo (sobrevive al install).

## Preparación única

1. Instalar APK release (WA-PROD-01/02 + WA-CONV-01 + WA-BUSINESS-01).
2. Ajustes → Notificaciones: conceder acceso de notificaciones a Nano.
3. Ajustes → Automatización → **Exención de batería: conceder** (sin esto
   Android bloquea el FGS desde el listener en background — esperado).
4. Ajustes → Automatización → Datos del negocio: cargar 1 producto real
   (nombre, variante, precio, stock), horario y envío.
5. Ajustes → Automatización: toggle "Procesar en segundo plano" en ON.
6. Regla reply creada y habilitada + modelo local cargado.

## WA-PROD-01 — runtime background (14 pasos del review)

1. Cerrar Nano completamente (swipe de recents).
2. Pantalla apagada u otra app al frente.
3. Llega WhatsApp de contacto con regla.
4. Logcat: NLS persiste → service FGS arranca (`automation-runtime`).
5. Nano procesa SIN abrir Activity (verificar: no aparece la UI).
6. Modelo local obtiene contexto (memoria conversacional).
7. Genera draft (traza `[draft]` — ver WA-CONV-01).
8. Regla autorizada permite reply (RuleExecutionAuthority).
9. ReplyCapabilityRef se revalida (CONTEXT_CHANGED si cambió).
10. RemoteInput despacha (code REMOTE_INPUT_ACCEPTED).
11. Journal registra estado honesto (no "delivered" inventado).
12. Sin duplicado (dedupe; un solo mensaje enviado).
13. Segundo mensaje continúa la conversación (memoria/historial).
14. Process kill/restart no rompe dedupe (matriz abajo).

## Matriz kill (por ventana de estado)

| Kill en | Esperado |
| --- | --- |
| RECEIVED (antes de claim) | Fila persiste; próximo wake la procesa |
| WAITING_MODEL (draft LLM) | Fila RESERVED; stale 30s → wake la retoma; sin doble envío |
| DISPATCHING (post-send) | Dedupe persistido; replay no reenvía |
| UI abierta a mitad de batch | Engine headless se detiene (single consumer); UI toma el hilo; sin doble reply |

Procedimiento: enviar mensaje; `adb shell am kill <pkg>` en la ventana;
repetir 3 veces por fila; verificar en WhatsApp receptor exactamente UNA
respuesta.

## Exención de batería ON/OFF

- ON: mensaje con app cerrada → responde (FGS visible unos segundos en la
  barra, luego desaparece en reposo — trabajo perceptible, sin notificación
  eterna).
- OFF: mensaje con app cerrada → NO responde; tile muestra "FALTA" en
  exención; al abrir Nano la cola pendiente se procesa (PENDING_WAKE honesto).
- Kill de ColorOS a mitad de batch: siguiente mensaje revive el proceso y
  retoma (kill-normal documentado).

## WA-CONV-01 — respuesta estructurada JSON

- Mensaje simple: responde normal, 1 línea.
- Mensaje con VARIAS preguntas: responde TODAS en orden (fallo típico del
  0.5B sin guía).
- Referencia ("¿y el negro?") tras historial de producto: resuelve contra la
  conversación previa.
- Ver en logcat la traza `[draft] sin reply parseable; raw=...` → debe estar
  VACÍA (o indicar qué escalón del parser falló con salida real del modelo).
- Recorte maxTokens: mensaje muy largo no debe devolver JSON como respuesta.
- Sin modelo/motor: NO responde (honesto, sin texto genérico).

## WA-BUSINESS-01 — datos del negocio

- Pregunta "¿cuánto vale?" con producto cargado → responde el precio REAL del
  bloque (con formato $ 899.000, sin inventar).
- "¿Tienes stock del negro?" con stock cargado → afirma el número real.
- Pregunta de dato NO cargado (ej. otro color, garantía) → pregunta/confirma,
  no inventa (missingFacts honesto).
- Ajustes → Datos del negocio: agregar/editar/borrar producto, horario y
  envío; cerrar y reabrir Ajustes → persisten (sección `business` SQLite).
- Editar un precio → el siguiente mensaje responde con el precio NUEVO (bloque
  leído en vivo, sin reiniciar).
- Sin datos cargados: el agente no afirma precios ni stock.

## WA-BUSINESS-02 — selector de hechos por mensaje

Con 3+ productos cargados (p.ej. negro 256GB, azul 128GB, tablet):

- "¿cuánto vale el negro?" → responde SOLO datos del negro (no confunde con
  otros productos; bloque contiene solo el matcheado).
- "¿y el azul?" (referencia posterior) → matchea por variante "azul".
- "¿qué modelos tienes?" → catálogo completo al prompt (resumen con verdad).
- "¿a qué hora atienden?" → horario al prompt.
- "¿hacen envíos?" → envío al prompt; sin mención de producto NO entran
  productos (bloque pequeño = menos tokens).
- Producto NO cargado ("¿tienes el s25 ultra?") → bloque vacío: el agente
  pregunta/confirma, jamás inventa especificaciones.

## WA-NATURAL-01 — tono de respuesta

- Toggle OFF (default): respuestas idénticas a antes (cero cambio).
- Toggle ON + Trato Formal: respuestas con trato formal/respetuoso.
- Toggle ON + Extensión Breve: respuestas cortas.
- Emojis ON: emojis con moderación; OFF: sin emojis.
- Venta Persuasivo vs Natural: diferencia perceptible en ofertas/recomendaciones.
- MI ESTILO (persona) + tono activos: MI ESTILO gana (el bloque lo declara;
  verificar que no haya conflicto visible ni mezcla de instrucciones).
- Cambiar un control → aplica desde el siguiente mensaje sin reiniciar.
- Persistencia: cerrar y reabrir Ajustes conserva el perfil.

## WA-TURN-01 — ráfagas por conversación (actor por chat)

- Mandar 3 mensajes seguidos ("hola" / "¿tienes el negro?" / "¿cuánto vale?")
  en <3s: UNA sola respuesta que contesta todo (logcat `[turn] agregados=3`),
  no tres respuestas fragmentadas.
- Mandar 2 mensajes con más de 3s de separación: dos turnos normales.
- Ráfaga mientras Nano genera (LLM ocupado): el mensaje nuevo NO se pierde —
  al terminar el turno en curso responde el siguiente (serialización; traza
  `[turn]` doble). Un solo envío por turno, jamás dos pipeline concurrentes
  del mismo chat.
- Enviar mensaje y verificar dedupe/cooldown siguen bloqueando ecos ("Tú:").
- Kill a mitad de ráfaga: solo se pierde la ventana de asentamiento en RAM;
  los eventos persistidos retoman su camino (sin doble envío).

## WA-CONV-03 — supersede (mensaje nuevo mata draft viejo)

- Enviar "¿tienes el negro?" y, mientras Nano redacta (~segundos), mandar
  "no, mejor el azul": el draft del negro NO se envía (logcat
  `[rules] … reason='turno superado…'`); el mensaje nuevo se responde.
- Ráfaga agregada normal sigue respondiendo UNA vez (sin supersede falso).
- Mensajes con >3s de separación: cada turno responde (sin supersede falso).

## FIX-VISUAL-01 — diseño estable al escribir (doble encogido)

- Mensajes y Dev (automatización): abrir el teclado NO aplasta ni solapa
  contenido — el diseño queda igual, la barra flota sobre el teclado.
- Dashboard Automatización: con teclado abierto el contenido no cambia de
  proporciones (scroll normal).
- Chat: regresión visual cero (mismo patrón ya documentado).

## WA-PROD-02 — estado durable

- Forzar cierre (kill) justo tras recibir mensaje → al reabrir Nano la
  conversación recuerda el hilo (memoria SQLite, migración única desde prefs:
  verificar una sola vez sin pérdida de historial previo).
- Reglas/dedupe intactos tras reinstalar APK encima (misma appId → misma DB).
