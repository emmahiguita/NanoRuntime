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

## WA-STATE-01 — contexto del cliente por conversación

- Día 1: cliente pregunta "¿tienes el negro?" (producto cargado en catálogo).
- Día 2: cliente escribe "¿y el que te pregunté ayer?" → responde sobre el
  negro (bloque <CONTEXTO DEL CLIENTE> en el prompt; traza/logcat revisable).
- Cliente pregunta por OTRO producto: el recuerdo se ignora (regla del
  bloque) y el nuevo producto reemplaza al anterior.
- Sin catálogo cargado: nunca se recuerda nada (selector sin match).
- Persistencia: cerrar/reabrir conserva el recuerdo (sección `convstate`).

## FIX-VISUAL-01 — diseño estable al escribir (doble encogido)

- Mensajes y Dev (automatización): abrir el teclado NO aplasta ni solapa
  contenido — el diseño queda igual, la barra flota sobre el teclado.
- Dashboard Automatización: con teclado abierto el contenido no cambia de
  proporciones (scroll normal).
- Chat: regresión visual cero (mismo patrón ya documentado).

## LINUX-PROD-01 — rootfs pinned

- Reinstalación limpia (borrar files/nano/usr + app data) con red:
  instala el bootstrap del pin (logcat `[rootfs] pin=bootstrap-2026.08.30…`),
  verifica SHA-256 y extrae; bash queda ejecutable.
- Sin red durante install: aborta fail-closed (nunca instala sin verificar).
- Rootfs viejo instalado (pre-pin): se conserva; logcat honesto
  (`[rootfs] instalado sin marker…` o `instalado=<tag viejo>`).
- Marker escrito tras instalar (`files/nano/rootfs-manifest.txt`);
  re-arranques muestran `[rootfs] pin verificado: …`.

## WA-EVLOG-01 — bitácora del pipeline

- Verificar con la app instalada y una regla activa: cada mensaje entrante
  deja su traza en la bitácora local (consulta opcional vía
  `adb exec-out run-as dev.nanoai.mobile cat databases/nano_automation_store.db`
  no aplica — sqlite directo requiere copia; alternativa: logcat ya traza
  `[rules]`). La bitácora es auditoría diagnóstica: no cambia comportamiento.
- Kill a mitad de pipeline: la fila `received` queda sin su `terminal`
  (evidencia honesta del corte) — el próximo wake no la reescribe.

## WA-ECHO-01 — evidencia local de envío (eco "Tú:")

- Responder a un mensaje con regla reply → WhatsApp publica el eco
  "Tú: <respuesta>" → la bitácora registra `echo` (eco local observado del
  envío reciente). Esto NO demuestra entrega: solo que el envío aterrizó en
  el hilo local (honestidad intacta: nada se marca como "entregado").
- Un texto idéntico llegado del cliente pasados los 3 min NO se confunde con
  eco (ventana).

## WA-PROD-02 — estado durable

- Forzar cierre (kill) justo tras recibir mensaje → al reabrir Nano la
  conversación recuerda el hilo (memoria SQLite, migración única desde prefs:
  verificar una sola vez sin pérdida de historial previo).
- Reglas/dedupe intactos tras reinstalar APK encima (misma appId → misma DB).

## WA-REG-01 — reparación de regresiones (runtime compartido, burst, barra, vocabulario)

Contexto: race de handoff headless→UI apagaba el runtime y el motor LLM
quedaba muerto para siempre en el proceso (EngineSupervisor irreversible).
Fixes: acquire(UI) síncrono, engine re-arrancable, BurstTurnGate por tanda,
relectura del slot al cambiar pestaña, vocabulario reply ampliado.

- **Race/handoff**: WhatsApp cerrado → recibir mensaje → esperar a que el
  servicio procese y quede idle → abrir Nano justo en esos momentos (ventana
  de ~1.5s) → orden escrita que use el LLM → debe funcionar. Repetir 3-4
  ciclos seguidos sin force-stop entre ellos (antes: un solo race dejaba
  todo muerto hasta matar el proceso).
- **Re-arranque del motor**: con la app abierta, matar el proceso nanortime
  (o debugKill desde Dev) → siguiente orden LLM debe re-arrancar el motor
  (antes: `Failed("supervisor en shutdown")` permanente).
- **Burst**: 3 mensajes rápidos consecutivos desde otro teléfono → todos
  obtienen su turno (ningún mensaje resuelto con resultados vacíos ni
  huérfano), respuestas no duplicadas, una sola por ráfaga.
- **Barra**: Dashboard → enviar A → Reglas → enviar B → Dashboard → enviar
  C → cada envío llega a la pantalla correcta (sin callback de la pestaña
  anterior).
- **Vocabulario**: «dile a Juan que sí» y una variante SIN tilde («escribele a
  Maria que llego») con notificación contestable → reply directo determinista
  sin LLM. «escribe un resumen» NO debe intentar responder un mensaje (sin
  falsos positivos de reply).

## DIAG-01 — comandos de diagnóstico deterministas

En la barra del Dashboard de Automatización:

- `@diag ping`: respuesta en la tarjeta de resultado con
  `DIAG PASS — input: PASS | engine: PASS | coordinator: PASS |
  native bridge: PASS | latency: N ms`. Sin LLM, sin WhatsApp, típicamente
  < 1s. Si algo sale FAIL, la razón dice exactamente qué eslabón cayó.
- `@diag llm`: arranca el motor si está caído y responde
  `DIAG LLM PASS — respuesta="ok" t=...`. Si sale `respondió vacío` =
  estado zombi (revive con /reload desde Dev o reiniciando el motor).
- Comando desconocido (`@diag x`): fallo honesto «Comando diag desconocido».
- `@diag` en una orden normal de WhatsApp NO debe interferir: los comandos
  solo se interceptan con el prefijo exacto «@diag ».
- Con audio ON: el diag se muestra en la UI y NO se habla por voz.

## WA-CTX-01 — contexto del motor LLM post-arranque + prompt compacto

Contexto: el planner del motor degradaba a `ctx=256` (survival_fit con RAM
mal medida) y el prompt WA de 5801 chars excedía ese contexto → «El motor
respondió vacío tras 3 intentos». Fix: el supervisor hace `/reload` con
`context_tokens=4096` si el motor arranca con contexto < 2048, y el prompt
se compactó (ejemplos 3→1, reglas 9→6).

- **Arranque frío del motor**: matar el proceso nanortime (o debugKill desde
  Dev) → siguiente orden LLM re-arranca el motor → logcat Kotlin debe
  mostrar `contexto degradado ctx=256 < 2048 — POST /reload` y luego
  `reload ctx=4096 aplicado`; `/api/status` queda en 4096 sin intervención.
- **Reply real**: mensaje de WhatsApp desde otro teléfono → responde en
  menos de ~3 min (prefill compacto), SIN «respondió vacío».
- **Calidad**: un "hola" no debe copiar el ejemplo del prompt («Déjame
  confirmar el stock…» solo si el cliente pregunta por stock).
- **Sin eco de ejemplo**: mensaje genérico ("¿cómo estás?") no menciona
  stock/negro/negocio si el cliente no lo trajo.

## NAV-FLOAT-01 — barra de navegación flotante de verdad, sin botones

Rediseño de la barra universal: fuera orbe búho, orbe de micrófono, botón
stop y botón enviar grande. Queda el campo de escritura (con iconos
compactos de dictado, adjuntar si aplica, limpiar y enviar) + dock de
pestañas. La barra ya NO reserva franja en el layout: el contenido pinta a
pantalla completa y cada pantalla reserva su propio espacio de scroll.

- **Sin botones**: en Inicio, Chat, Modelos, Terminal, Ajustes y Automatización
  la barra muestra SOLO campo + pestañas. No hay búho, no hay orbes, no hay
  botón rojo de stop ni botón azul de enviar.
- **Vertical**: en cualquier pestaña, hacer scroll hasta el final — el último
  contenido (mensaje del chat, última regla, último ajuste, último modelo)
  queda COMPLETAMENTE visible encima de la barra, nunca tapado.
- **Horizontal (landscape)**: rotar — la barra compacta flota centrada sin
  tapar el último contenido de la lista; el chat en modo escritorio conserva
  su panel.
- **Fondo completo**: el fondo líquido/ambiental se ve hasta el borde
  inferior de la pantalla (sin franja cortada bajo la barra).
- **Escribir**: tocar el campo abre el teclado y el contenido sube lo justo
  (sin doble encogido); con texto escrito aparece el icono de enviar (flecha)
  y funciona (Enter NO envía — multilínea).
- **Dictado**: el icono de micrófono (compacto, dentro del campo) dicta al
  campo en vivo; se pone rojo mientras escucha.
- **Adjuntar en Chat**: el clip del campo sigue abriendo la hoja de adjuntos.
- **Cancelar generación**: el botón stop YA NO existe en la barra (fuera por
  diseño; cancelar desde otra vía queda como trabajo pendiente si se usa).
- **Navegación**: las 6 pestañas siguen navegando igual (el acceso al chat
  ahora es solo la pestaña Chat, ya no el búho).

## PERSONA — Personal Agent Runtime (12 sprints)

Contexto: Nano deja de ser «borrador inteligente» y pasa a agente personal:
decisión determinista (FACTS → DECISION → PERSONA → SEND), ownership
bot/humano durable por conversación, perfil del dueño + relaciones +
ejemplos de estilo con FTS4. Una sola llamada LLM por turno; el modelo
propone texto, el engine decide. Regla de oro: cero respuestas automáticas
mientras el humano atiende la conversación.

- **Paridad (sin datos cargados)**: mensaje normal de WhatsApp con regla
  reply → responde como antes (sin bloque persona: cadena vacía, prompt
  idéntico a WA-CTX-01). Ningún cambio visible.
- **Perfil del dueño**: Ajustes → Agente personal: nombre + notas → guardar.
  Mensaje "¿quién atiende?" → el agente presenta al dueño por su nombre
  (no inventa datos fuera de las notas).
- **Relación por contacto**: crear contacto «Juan» con nota «cliente
  frecuente, trato de confianza» → mensaje de Juan → respuesta acorde
  (traza logcat `[draft]` sin errores; el bloque entra al prompt).
- **Ejemplos de estilo**: añadir ejemplo «¡Hola Juan! Sí, el negro está
  disponible. ¿Te lo aparto para hoy?» → mensaje parecido de Juan → la
  respuesta imita la FORMA del ejemplo sin copiarlo textual.
- **Recorte honesto**: notas del dueño con 2000+ chars → logcat
  `[persona] validator rechazó: …` (bloque recortado, sin romper el
  prompt) y la respuesta sigue saliendo.
- **Ownership — tomar control**: pantalla Mensajes → seleccionar
  conversación contestable → «La atiendo yo» → mensaje nuevo de ESA
  conversación → Nano NO responde (logcat `[decision] … holdForApproval`);
  OTRA conversación sin control sigue respondiendo.
- **Ownership — devolver**: «Devuélvelo a Nano» → mensaje nuevo → Nano
  responde normal.
- **Ownership — responder manual**: pantalla Mensajes → responder y enviar
  desde Android → la conversación queda marcada como humana sola (patrón
  Chatwoot) y Nano no la pisa hasta devolvérsela.
- **Autonomía por identidad**: notificación SIN locusId/shortcutId (app
  sin evidencia estable) → draft retenido con traza `[decision] identidad
  débil`; con evidencia estable (WhatsApp) → envío normal.
- **Persistencia**: cerrar y reabrir Nano → perfil/relaciones/ejemplos
  siguen (SQLite v3); ownership sobrevive a kill.
- **Sin regresión WA**: órdenes escritas siguen 100/100; ráfagas sin
  duplicados; @diag ping/llm intactos.

## CONTEXT-GATE-01 — gating determinista de contexto conversacional

Contexto: evidencia física de contaminación — tras una consulta del Negro
($500), un "Hola" respondió con el Negro y su precio. Causa: el recuerdo
<CONTEXTO DEL CLIENTE> y el historial entraban al prompt SIEMPRE, con la
relevancia delegada al LLM ("ignóralo si no aplica"). Corrección: la
información irrelevante no llega al prompt. Regla: MEMORIA DISPONIBLE !=
MEMORIA RELEVANTE; el mensaje ACTUAL decide.

- **M01 — saludo en conversación nueva**: WhatsApp cerrado → mensaje "Hola"
  de un contacto nuevo → respuesta = saludo natural. Sin producto, sin
  precio, sin CTA de compra.
- **M02 — saludo tras producto**: tras conversar del Negro → mensaje "Hola"
  → saludo. NO menciona el Negro ni $500 (antes los repetía).
- **M03 — referencia explícita**: tras conversar del Negro → "¿y ese
  todavía está disponible?" → resuelve al Negro con datos reales.
- **M04 — saludo + producto**: "hola, ¿cuánto vale el Negro?" → saludo +
  precio real.
- **M05 — producto + envío**: "¿tienen el Negro y hacen domicilio?" →
  responde ambas con datos reales del bloque de negocio.
- **M06 — párrafo grande**: saludo + producto + precio + stock + domicilio +
  fecha en UN mensaje → responde TODAS en orden; lo que no tenga dato real
  lo pregunta o lo marca (jamás inventa).
- **M07 — tema nuevo**: tras hablar del Negro → "necesito saber el horario
  de mañana" → responde horario. Sin mencionar el Negro.
- **M08 — respuesta corta dependiente**: Nano pregunta "¿confirmo el
  pedido?" → cliente responde "sí" → resuelve contra el turno activo
  (el recuerdo SÍ entra con "sí").
- **M09 — no duplicar**: "Hola Emma" no debe salir si el mensaje es "Hola"
  (la regla de no repetir nombre ya existe; el gating quita el incitador).
- **M10 — sin regresión**: órdenes escritas, ráfagas, @diag intactos;
  logcat `[decision] autoSend` para un saludo limpio.

## Ronda 3 — Conversation Engine (pendingQuestion + topicStatus)

Contexto: respuestas cortas ("sí", "M", "mañana") se resolvían contra el
último producto por keyword; ahora se resuelven contra la PREGUNTA PENDIENTE
que Nano dejó abierta (reply enviado terminado en '?'). Un agradecimiento
cierra el tema: no reaparece con saludos. Trazas: `[ctx:gate]` y
`[ctx:prompt]` en logcat (una línea por turno, se quitan tras validar).

Misma conversación, en orden, WhatsApp cerrado:

- **C01 — pregunta pendiente**: cliente "¿tienen el Negro?" → Nano responde
  (con '?' final, p.ej. "¿quieres que revise disponibilidad?") → cliente
  responde "sí" → Nano resuelve la disponibilidad. Sin repetir el catálogo.
- **C02 — talla**: Nano pregunta "¿qué talla necesitas?" → cliente "M" →
  Nano entiende M como respuesta a la talla (no consulta nueva).
- **C03 — vale**: tras una pregunta pendiente → cliente "vale" → Nano lo
  interpreta como confirmación de la pregunta. SIN consulta de precio
  inventada.
- **C04 — cuánto vale**: tras hablar del Negro → "¿cuánto vale?" → precio
  del Negro (la señal 'cuanto' gana sobre la pregunta pendiente).
- **C05 — cierre**: tras el tema del Negro → "listo gracias" → Nano se
  despide. Después "Hola" → saludo limpio SIN Negro/$500.
- **C06 — referencia tras cierre**: tras C05 → "¿y ese todavía está
  disponible?" → recupera el Negro aunque el tema estaba cerrado
  (referencia explícita siempre gana).
- **C07 — tema nuevo**: tras hablar del Negro → "¿qué horario tienen
  mañana?" → horario. Sin Negro.
- **C08 — párrafo grande**: saludo + producto + precio + stock + domicilio
  + fecha en UN mensaje → responde todas las que tengan dato real.
- **C09 — ráfaga**: "oye" / "una cosa" / "¿el negro lo tienen?" seguidos →
  un solo turno coherente.
- **C10 — sin regresión**: traza `[ctx:gate]` muestra `clientContext=false`
  para "Hola" tras producto; `[ctx:prompt]` con historyEntries correcto.

## Ronda 5 — Autonomía conversacional (AUTO-01..AUTO-03 + consolidaciones)

Contexto: sprint mínimo autónomo tras la auditoría de 4 frentes. Lo nuevo:
(1) Router de rol determinista PURO (personal/sales/general — jamás LLM),
(2) Modo de autonomía global (Desactivado/Sugerencias/Auto seguro/Autónomo)
como tope del MISMO ConversationDecisionEngine (no hay segundo motor),
(3) Fix del eco de plantilla del prompt JSON (placeholders vacíos, ejemplo
fuera). Consolidaciones: umbral identidad 0.95 única fuente, memoria
máxima real 60 entradas, timeout 60s del arranque del motor (sin colgar
turnos). Trazas nuevas en logcat: `[agent]` (rol+modo por mensaje) y las
razones de `[decision]` ya existentes. Default = Autónomo = comportamiento
previo exacto.

WhatsApp cerrado para toda la tanda. Contactos: A = desconocido, B =
contacto con relación registrada (Ajustes → Agente personal).

- **A01 — routing sales**: A: "¿tienen el negro?" (producto en catálogo) →
  logcat `[agent] rol=sales` ("producto explícito"). Respuesta con datos.
- **A02 — routing personal**: B: "hola bro qué haces" → `rol=personal`
  ("saludo puro + relación registrada"). Saludo natural.
- **A03 — routing general**: A: "hola" → `rol=general`. Saludo natural.
- **A04 — relación sin señal comercial**: B: "gracias bro" → `rol=personal`
  ("relación registrada sin señal comercial").
- **A05 — referencia corta comercial**: tras hablar del Negro con A →
  "¿y ese todavía está?" → `rol=sales` ("referencia sobre producto activo").
- **A06 — modo Desactivado**: Ajustes → Autonomía de WhatsApp →
  Desactivado → mensaje entrante → logcat `[decision]` retiene con
  "autonomía desactivada"; NO se envía nada.
- **A07 — modo Sugerencias**: mismo camino con Sugerencias → retiene con
  "modo sugerencias"; no se envía (la cola de aprobación es sprint futuro;
  hoy se descarta y se traza).
- **A08 — modo Auto seguro**: saludo simple de A → `autoSend`. "¿tienen el
  negro?" SIN stock en catálogo → retiene ("safeAuto: ... hechos
  faltantes"). Con stock informado → autoSend con dato verificado.
- **A09 — modo Autónomo**: vuelta al comportamiento completo (riesgo bajo
  sale; alucinación se retiene). Mismo que antes de Ronda 5.
- **A10 — persistencia del modo**: elegir Desactivado → force-stop Nano →
  reabrir → Ajustes muestra Desactivado todavía (shared_prefs).
- **A11 — sin eco de plantilla**: A: "Hola" → reply SIN `[Pregunta del
  cliente]`, sin `"questions": [...]` copiado, sin parafraseo del ejemplo
  viejo ("¿Tiene algún producto en stock?"). Traza `[draft]` si algo raro.
- **A12 — memoria acotada real**: conversación larga (>60 mensajes) →
  logcat `[ctx:prompt] historyEntries=` nunca pasa de 60.
- **A13 — sin turno colgado**: motor frío (recién abierta) + mensaje
  entrante → si el motor no arranca en 60s, traza "[draft] ensureReady
  agotó 60s" y el turno CIERRA (antes podía colgarse minutos).
- **A14 — identidad débil**: notificación sin evidencia estable de
  plataforma (si la hay en tu Oppo) → retiene con "identidad débil"
  (umbral 0.95, única fuente).
- **A15 — ownership humano**: A conversando → "La atiendo yo" desde
  Mensajes → siguiente mensaje se retiene SIEMPRE ("ownership: humano
  controla la conversación").
- **A16 — sin regresión**: órdenes escritas, ráfagas (3 mensajes seguidos
  = 1 turno coherente), @diag ping/llm, reglas y ticker de hora intactos;
  `flutter analyze` 0 errores.

## WA-UNIV-01 — regla universal de conversación de WhatsApp (seed del sistema)

Regla de sistema sembrada por el RuleRegistry al arrancar (id fijo
`wa_universal_conversation`): APP=WhatsApp, FILTER=sin keyword obligatoria,
ACTION=respuesta dinámica del Conversation Engine (LLM), AUTO REPLY.
Sin ella el Personal Agent no recibe ni un "Hola" tras reinstalar.

Cadena a verificar por traza (logcat, grep `flutter.*\[`):
RECEIVED (`[notify-event]`) → RULE MATCH (`[rules] cargadas=5 matcheadas>=1`)
→ TURN (`[turn]`) → DRAFT (`[draft:start/end]`, `[route] rol=…`) → DECISION
(`[decision]`) → DISPATCH (`[dispatch]`).

- **U01 — seed al arrancar**: instalar APK (force-stop previo) → abrir Nano
  → logcat muestra `[rules] seed universal WhatsApp` UNA vez → tick de
  reglas pasa a `cargadas=5` (4 viejas + universal).
- **U02 — hola sin keyword**: WhatsApp CERRADO en el Oppo (abierto = solo
  GROUP_SUMMARY, el pipeline no ve el mensaje — evidencia ColorOS) → desde
  OTRO teléfono: "Hola Emma" → traza completa RECEIVED→DISPATCH y reply
  llega al remitente.
- **U03 — regla visible**: Ajustes → Reglas → aparece la card
  "Responder · com.whatsapp" con toggle ON. Desactivar el toggle →
  `[rules] cargadas=5` con la universal desactivada (matcheadas baja) →
  reactivar.
- **U04 — borrado + reaparición**: borrar la universal en Reglas → reiniciar
  Nano (force-stop + abrir) → reaparece (regla de sistema, no borrable).
  Editar la universal → reiniciar → la edición se conserva (el seed solo
  mira la existencia del id).
- **U05 — reglas específicas ganan**: con la universal activa, una regla
  keyword ("cuando digan 'negro' responde '…'") sigue disparando primero
  para ese texto (orden: específicas antes, universal al final).
- **U06 — no WhatsApp = no dispara**: notificación de otra app (Gmail,
  Telegram) → `[rules] cargadas=5 matcheadas=0` para ese evento (la
  universal no toca otros paquetes).
- **U07 — fail honesto sin remitente**: notificación de WhatsApp sin
  remitente (poco común) → dispatcher falla honesto "sin remitente",
  nada se envía.

## WA-UNIV-02/03 — eco propio ignorado + historial mínimo anti-eco

Dos bugs emergentes de la universal, vistos en vivo en Oppo (2026-09-06):

- **Eco propio matcheaba la universal**: WhatsApp marca los mensajes PROPIOS
  con sender "Tú" en la notificación. La universal (sin senderMatch) matcheaba
  el eco de NUESTRO RemoteInput → turno sobre nuestro propio mensaje
  (evidencia: `matcheadas=1 (com.whatsapp/Tú)` + `verdict=proceed`). Guard
  determinista en el router ANTES del gate: sender "Tú" de com.whatsapp se
  descarta con traza `[rules] eco propio WhatsApp (sender=Tú) ignorado`.
  El bounceback por texto (WA-ECHO-01) quedaba corto: depende de ventana de
  3 min y de que el outbound post-terminal sobreviva a un kill.
- **Eco de historial en el reply**: el reply de "ESTA TU PAPA EN CASA" salió
  como COPIA literal de la conversación previa (`[draft:end] reply="¡Hola!
  ¿En qué puedo ser útil hoy? Emm: como estas Nano: …"`) y se DESPACHÓ.
  Causa: ctx=256 del survival_fit evicta las reglas del system (sliding
  window) y el modelo solo ve el diálogo del historial → lo continúa como
  respuesta. Fix: historial mínimo en el prompt (3 entradas × 80 chars).

- **V01 — eco propio no dispara**: con la universal activa, responder a un
  mensaje real (el eco aparece a los segundos) → logcat muestra
  `[rules] eco propio WhatsApp (sender=Tú) ignorado` y NINGÚN `[turn]` ni
  `[draft]` para ese eco. Antes: `matcheadas=1 (com.whatsapp/Tú)`.
- **V02 — reply sin copia de historial**: conversación con historial previo
  (varios intercambios) → mensaje nuevo → `[draft:end]` reply responde al
  mensaje nuevo sin repetir el diálogo anterior.
- **V03 — referencia corta aún funciona**: tras varios intercambios,
  "¿cuál era el precio?" → el reply resuelve contra las últimas 3 entradas
  (historial mínimo basta para referencias).

## P0-ROUTE-02 — corrección definitiva del motor conversacional (2026-09-06)

Prompt arquitectónico del usuario: el agente debe dejar de decidir "cómo
responder" antes de saber QUÉ AGENTE corresponde. Cambios:

- **Router** (`conversation_agent_role.dart`): saludo puro → PERSONAL SIEMPRE
  (fuera la rama "saludo puro sin relación registrada" → GENERAL, causa raíz
  del call-center); social casual corto ("que haces", "jajaja", "bro") →
  PERSONAL; familia del dueño + verbo de presencia ("¿está tu papá?") →
  PERSONAL; `commercialIntent` ORTOGONAL al rol para turnos mixtos.
- **Writer**: corrección meta-conversacional ("¿cuál negro de qué hablas?")
  entra con historial LIMPIO (igual que saludo puro — el tema viejo no se
  continúa); `<DATOS DEL NEGOCIO>` entra con rol sales O commercialIntent
  (turno mixto = estilo personal + facts reales, UNA respuesta).
- **Prompt**: sección P0-SOCIAL (mensaje social → responder como la persona
  del dueño, prohibido lenguaje de operador); regla 5 solo con pregunta
  explícita de identidad (un "hola" NO la es).

Pruebas físicas (Oppo, WhatsApp cerrado antes de enviar):

- **PERSONAL-01 — hola**: enviar "hola" → logcat `[route] rol=personal
  commercial=false saludo puro (social)`; reply corto social, SIN "¿En qué
  puedo ayudarte?" ni "Soy Nano".
- **PERSONAL-02 — como estas**: "como estas" → rol personal, reply estilo
  dueño (con MI ESTILO poblado) o coloquial corto.
- **PERSONAL-03 — oe / estas ahi**: "oe" y luego "estas ahi" → rol personal
  las dos; reply corto ("si que paso" si el estilo del dueño lo trae).
- **PERSONAL-04 — que haces bro**: → rol personal (social casual).
- **PERSONAL-05 — jajaja**: → rol personal, reply relajado.
- **PERSONAL-06 — esta Emmanuel?**: → rol personal (identidad), reply NO
  afirma disponibilidad: ofrece dejar el mensaje.
- **PERSONAL-07 — esta tu papa? / ESTA TU PAPA EN CASA**: → rol personal
  (familia + presencia), reply no afirma: ofrece dejar mensaje.
- **SALES-01 — cuanto vale el Negro**: → `[route] rol=sales commercial=true
  producto explícito + señal comercial`; reply con precio del catálogo.
- **SALES-02 — tienen disponible el Negro**: → rol sales, reply con stock
  real o pregunta honesta.
- **NON-SALES-01 — los pongo a chupar la crema alpina**: → `[route]`
  producto sin señal comercial, rol personal o general, NINGÚN
  `<DATOS DEL NEGOCIO>` (`[ctx:prompt] businessChars=0`).
- **NON-SALES-02 — negro hp**: → sin contexto comercial, reply social.
- **CORRECTION-01 — cual negro de que hablas** (tras consulta del Negro):
  → rol personal (corrección), historial limpio, reply responde al mensaje
  actual SIN seguir hablando del Negro.
- **TOPIC-01 — gracias → hola**: tras cerrar un tema con "gracias", un
  "hola" posterior → rol personal SIN reactivar el producto
  (`[ctx:gate] clientContext=false`).
- **MULTI-01 — hola bro, esta Emmanuel y todavia tienen el Negro?**: →
  `[route] rol=personal commercial=true` (identidad manda) y
  `[ctx:prompt] businessChars>0`: UNA respuesta con estilo personal y los
  facts del Negro, sin dos agentes.

---

# Ronda 4 — Inteligencia Conversacional (2026-09-07)

Capa nueva de diálogo humano sobre el pipeline de Ronda 3/P0-ROUTE. Cambios
(sin commit aún — validar antes):

- **CONV-SEM-01/02/03** — `relation` en el JSON del draft (nueva/continua/
  responde/cambia/corrige/rechaza/''), declarada por la MISMA inferencia
  (jamás segunda pasada LLM); traza `[understanding]`; corrige/rechaza +
  reply ASERTIVO → holdForApproval (contexto deshecho = no afirmar);
  corrige/rechaza + reply PREGUNTA → riesgo medio y sigue (reparación
  honesta).
- **CONV-SOC-02** — `_socialWindow` exige inbound social ANTES de admitir
  cada outbound (outbound huérfano fuera: no hay continuidad que mostrar).
- **CONV-STATE-02** — rama nueva del router: respuesta a la pregunta
  pendiente de Nano (≤3 tokens, sin señal comercial) → PERSONAL con
  `pendingReply` (bloque `<PREGUNTA PENDIENTE>` entra en turnos
  personales); con producto explícito ("la negra") → SALES.
- **CONV-STATE-03** — `recordTurn(correction: true)`: el recuerdo de
  producto y el tema activo se INVALIDAN en corrección/rechazo (un "sí"
  posterior no reactiva producto deshecho). Señal: `isCorrectionMessage`
  en `onTurnComplete`.
- **CONV-PROMPT-02** — bloque `<DATOS DE LA PERSONA>` sin framing de
  "asistente del negocio": "El dueño es X; responde como lo haría él"
  (alineado con la regla 5 del prompt).
- **H7-GUARD** — P0-NO-CALLCENTER ahora cubre PERSONAL **y** GENERAL
  (muletillas de operador retenidas en ambos; SALES/SUPPORT intactos).

## Matriz de validación física (Oppo, WhatsApp cerrado antes de enviar)

Contexto previo (crear en la conversación de prueba):

- **S1**: enviar "¿cuánto vale el Negro?" → Nano responde con precio → luego
  enviar "¿cuál prefieres? negra o roja" no aplica (esa la pregunta NANO):
  usar "¿tienen el Negro?" y que el reply de Nano pregunte algo
  (ej. "¿de qué tamaño?" o confirmación con '?'), anotar la pregunta exacta.

Pruebas:

- **C01 — hola (frío)**: arranque → "hola" → `[understanding] relation=""` o
  "nuevo", `[ctx:gate] clientContext=false`, reply social sin operador.
- **C02 — hola tras consulta del Negro**: "hola" después de S1 → NO
  menciona el Negro ni precio (`[ctx:prompt] clientContext=false`).
- **C03 — ese teléfono**: tras S1, "¿y ese todavía está?" → rol sales,
  `[ctx:gate] reference=true clientContext=true`, reply con precio real.
- **C04 — bien**: tras S1, "bien" → saludo puro (greetingTokens), prompt
  social, SIN recuerdo del Negro.
- **C05 — si / dale / listo**: tras una pregunta de Nano terminada en '?',
  responder "sí" → `[route]` "respuesta a la pregunta pendiente de Nano" o
  dependent; reply continúa el diálogo, sin inventar.
- **C06 — M (dato corto)**: tras pregunta de talla/elección de Nano,
  responder "M" → `[route] rol=personal pendingReply=true`,
  `[ctx:prompt] clientContext=true` (bloque pregunta pendiente) y reply
  resuelve "M" contra la pregunta (no "M" suelto).
- **C07 — la negra (elección)**: tras pregunta de elección de Nano
  ("¿negra o roja?"), responder "la negra" → rol sales (producto
  explícito), reply con los facts del Negro.
- **C08 — cual negro de que hablas**: tras S1 → rol personal (corrección),
  `[understanding] relation=corrige` (o reply pregunta), historial limpio,
  y `[route]` confirma corrección; NINGUNA mención del Negro después.
- **C09 — no es eso / no pregunte eso**: variante de C08 → mismo
  comportamiento; verificar que tras la corrección un "sí" posterior NO
  reactiva el Negro (`[ctx:gate] clientContext=false`).
- **C10 — me alegra que estes bien**: reacción social larga → rol personal,
  prompt social mínimo, reply corto sin ofrecer ayuda.
- **C11 — esta tu papa?**: → rol personal (familia), reply ofrece dejar
  mensaje, jamás afirma disponibilidad.
- **C12 — gracias → hola**: cerrar tema con "gracias" → "hola" → SIN
  producto reactivado (`[ctx:gate] clientContext=false`).
- **C13 — multi-pregunta**: "¿tienen el Negro? ¿y cuánto vale?" → reply
  responde TODAS (stock + precio), `[understanding] questions=2`.
- **C14 — referencia ambigua**: "¿y el otro?" sin producto claro → reply
  PREGUNTA de aclaración (no inventa), requiereAction true.
- **C15 — broma casual**: "jajaja" → rol personal, reply relajado.
- **C16 — corrección + afirmación**: tras S1, "no, te pregunté por la roja"
  → `[understanding] relation=corrige` + reply asertivo → `[decision]`
  holdForApproval (retiene; jamás afirma precio del Negro).
- **C17 — corrección + pregunta**: "no, ¿cuánto vale la roja?" → relation
  corrige + reply pregunta → envío con riesgo medio (no retiene).
- **C18 — desconocido casual**: remitente SIN relación envía "que haces
  bro" → rol personal (social puro, jamás general).
- **C19 — desconocido saluda**: remitente sin relación, "hola" → rol
  personal; reply sin "Soy Nano" ni "¿en qué puedo ayudarte?".
- **C20 — desconocido general**: mensaje misceláneo sin señales ("mañana
  llueve") → rol general; si el reply trae muletilla de operador →
  holdForApproval (H7-GUARD), traza `[decision]` P0-NO-CALLCENTER.
- **C21 — saludo + identidad**: "hola, ¿quién eres?" → saludo NO puro
  (token fuera del set) → reply puede decir "Nano"; "hola" solo NO.
- **C22 — historial social**: secuencia "hola" → reply → "¿cómo estás?" →
  reply; en el tercer turno `[ctx:prompt] historyEntries>0` SOLO con
  entradas sociales (sin producto), reply continúa la conversación social.
- **C23 — outbound huérfano**: si en el historial Nano respondió social sin
  inbound social previo, el prompt social no lo muestra (verificar
  `[ctx:prompt] historyEntries` bajo).
- **C24 — estado persistente**: tras C06, matar y reabrir la app → la
  pregunta pendiente sobrevive (convstate SQLite): un nuevo "M" sigue
  resolviendo contra ella.
- **C25 — KV por turno**: dos turnos seguidos → `[draft]` con
  `session=` DISTINTOS cada turno (fingerprint único); latencia estable
  (prefix cache V1.1: prefill estático amortizado).
- **C26 — ráfaga**: 3 mensajes rápidos seguidos → un solo turno agregado
  (BurstTurnGate), reply cubre el último estado.
- **C27 — supersede**: mensaje nuevo mientras el draft corre → el draft
  viejo NO se envía (`[supersede]`), el nuevo sí.
- **C28 — estilo del dueño**: con MI ESTILO poblado, "hola" responde con
  la forma del dueño (frases/longitud), sin repetir el bloque de estilo.
- **C29 — hechos reales**: "¿cuánto vale el Negro?" → precio exacto del
  catálogo; "¿cuánto vale el Azul?" (inexistente) → reply pregunta/pide
  dato, jamás inventa precio.
- **C30 — trazas**: cada prueba deja `[route]`, `[ctx:gate]`,
  `[understanding]`, `[draft:end]` y (si aplica) `[decision]`/`[dispatch]`
  consistentes; ningún turno queda sin traza de entendimiento.

---

## PROD AUTONOMY FAIL-SAFE (cierre de producción, 2026-09-07)

P0: instalación nueva, setting ausente/corrupto o valor inválido JAMÁS
llega a FULL AUTONOMOUS sin elección explícita persistida del dueño.
Conversión en 3 vías: nombre válido → ese modo; null (nunca elegido /
fresh / legacy sin key) → safeAuto; inválido → disabled.

- **A01 — fresh install**: borrar datos de la app (o instalación limpia) →
  card "Autonomía de respuestas" en Ajustes dice "No has elegido aún —
  Nano solo responde lo seguro."; logcat `[agent] ... modo=safeAuto`.
  Un "hola" puede responder (saludo = riesgo bajo); un pedido de datos
  ausentes debe retenerse (`[decision]` holdForApproval/safeAuto).
- **A02 — valor inválido**: estático (sin root no se inyecta shared_prefs):
  `fromName('autonomus')` → disabled. Verificación de código, no física.
- **A03 — elección explícita**: Ajustes → Autonomía → "Autónomo" →
  logcat `[agent] ... modo=autonomous`; matar y reabrir la app → la card
  sigue en AUTÓNOMO (persistido) y el modo sigue autonomous.
- **A04 — elección Desactivado**: Ajustes → "Desactivado" → ningún envío
  automático (`[decision]` autonomía desactivada); reabrir la app →
  sigue Desactivado.
- **A05 — legacy sin key**: instalación antigua actualizada SIN borrar
  datos (settings JSON sin `waAutonomyMode`) → card "No has elegido aún",
  logcat modo=safeAuto (antes era autonomous — cambio de comportamiento
  intencional del fail-closed; el dueño elige Autónomo si lo quiere).

## PROD MULTI-MATCH REGRESSION (falla reproducida 2026-09-07)

Evidencia física: "Hola" matcheó 3 reglas reply → 3 borradores LLM
(`[draft:start]` x3, `[rules] terminal=...failed resultados=failed,failed,failed`).
Fix: el INTENTO de reply cierra la puerta para las reglas reply siguientes
(antes solo el aterrizaje — isReplyAttempt). Regresión a repetir:

- **A06 — un input = un draft**: enviar "Hola" → logcat muestra UN solo
  `[draft:start]` y `[rules] terminal=...` con UN resultado reply
  (failed o replyVerified) + los demás `ignored`. Jamás [draft:start] x3.

## PROD SOCIAL-03 (falla reproducida 2026-09-07)

Evidencia física: "Bien y tu, como estas?" (respuesta real al saludo de
Nano) → rol=general (faltaba 'bien' en socialReactionTokens) + reply eco
"¿Cómo estás?" con intent="" → hold safeAuto. Fix: token 'bien' + exención
de intent en turno social corto (isSocialReactionMessage).

- **A07 — conversación social sostenida**: tras el saludo (A05), responder
  "Bien y tú, ¿cómo estás?" → logcat `[agent] rol=personal` + reply social
  propio (sin eco ni "Soy Nano") + `[dispatch]` en safeAuto. Un "bien,
  ¿cuánto vale el Negro?" debe seguir ruteando SALES (ramas anteriores).

## PROD ECO-01 (falla reproducida 2026-09-07, 14:19:38)

Evidencia física: input "BIEN Y TU COMO ESTAS?" → reply "Bien y tú, como
estas?" despachado al cliente (REMOTE_INPUT_ACCEPTED). Eco literal = el
modelo repitió el mensaje con contexto degradado: calidad cero. Fix:
guard determinista por igualdad normalizada (fold + puntuación fuera) en
ConversationDecisionEngine — holdForApproval con razón "reply eco del
cliente: el modelo repitió el mensaje".

- **A08 — eco retenido**: enviar un mensaje y esperar reply que repita el
  texto del cliente → logcat `[decision]` con razón "reply eco del
  cliente..." y terminal sin `replyDispatched` (hold). Un saludo
  legítimo ("hola" → "Hola, ¿cómo estás?") sigue saliendo: la igualdad
  normalizada jamás matchea un reply que AÑADE contenido.

## PROD SOCIAL-04 (falla reproducida 2026-09-07, 14:18:05)

Evidencia física: "Si creo mano jajajaja" (4 tokens) → rol=general: los
tokens de risa solo estaban en la rama casual ≤3 tokens. Fix: los 16
tokens casuales (haces/haciendo/jajaja/jajaj/jaja/jeje/jajajaja/bro/
parce/parcero/mano/amigo/amiga/socio/cuentame/contame) añadidos a
socialReactionTokens (rama de cualquier longitud).

- **A09 — risa/vocativo rutea personal**: enviar "Si creo mano jajajaja"
  → logcat `[agent] rol=personal reacción social` + `[dispatch]` en
  safeAuto (reply social, sin fallback comercial). No debe caer a
  GENERAL.

## PROD SOCIAL-05 (falla reproducida 2026-09-07, 14:23:50)

Evidencia física: "Jajajsjsjsja" (risa con typo de teclado) → rol=general:
el matching social es token-exacto y ningún token cubre risa desordenada.
Fix: patrón determinista acotado (ja/je/ji/jo repetido, sin diccionario)
— rama "risa (patrón desordenado)" en el router + exención de intent en
el decision engine (misma familia que PROD-SOCIAL-03).

- **A10 — risa con typo rutea personal**: enviar "Jajajsjsjsja" →
  logcat `[agent] rol=personal` con razón "risa (patrón desordenado)" +
  `[dispatch]` en safeAuto (reply social, sin degrada por intent ausente).

## RONDA 5 — COHERENCIA CONVERSACIONAL (brief 2026-09-07)

Objetivo: reply COHERENTE + RELEVANTE + CONTEXTUAL + NO INVENTADO.
Trazas temporales de diagnóstico: [persona:retrieve], [persona:example],
[reply:quality] (se quitan tras la evidencia).

- **H01 — saludo natural**: "Hola" → saludo natural. Prohibido:
  bienvenido / cómo puedo ayudarte / soy Nano.
- **H02 — eco no trivial**: "BIEN Y TU COMO ESTAS?" → responder cómo está
  con continuidad natural. Prohibido: copiar la pregunta.
- **H03 — secuencia social**: "¿Cómo estás?" → "Bien" → "Y que haces?" →
  el último reply responde QUÉ HACES. Prohibido: "bien, gracias por
  preguntar".
- **H04 — no copiar estado de ejemplos**: "qué haces?" con PersonaExamples
  que contengan salón/trabajando/comiendo → NO copiar esos estados como
  presente.
- **H05 — no inventar actividad**: "qué haces ahora?" sin LiveOwnerState
  verificable → NO inventar actividad; disposition según política real.
- **H06 — repair anclado**: tras respuesta incoherente de Nano, "eso esta
  mal" → repair vinculado al reply anterior. Prohibido: qué quieres que
  haga / cómo puedo ayudarte.
- **H07 — pregunta directa**: "te pregunte que haces ahora" → intent
  correcto (actividad actual). Prohibido: "me encanta la forma en que lo
  haces".
- **H08 — par condicionado**: ejemplo par {incoming:"cómo estás",
  owner:"todo bien y vos"} + mensaje "cómo vas?" → puede usar el patrón
  (forma recíproca corta).
- **H09 — par NO seleccionado por similitud pobre**: mismo ejemplo +
  "qué haces?" → NO seleccionarlo.
- **H10 — hecho pasado no es presente**: ejemplo {incoming:"dónde estás?",
  owner:"en el salón"} + "dónde estás?" al día siguiente → NO contestar
  "en el salón" sin estado presente verificado.
- **H11 — aislamiento por contacto**: A tiene examples/relación; B
  pregunta "qué haces?" → ningún dato de A.
- **H12 — turnos repetidos**: "que haces" x3 → cada evento humano = turno
  distinto, sin stale draft ni copia del reply anterior.
- **H13 — burst mismo contacto**: "Hola" / "bien" / "y tú" / "qué haces?"
  enviado rápido → 1 logical turn, 1 reply final que responde al conjunto,
  no cuatro respuestas.
- **H14 — mensaje durante generación**: A: "Hola" [inferencia en curso]
  A: "Oye qué haces ahora?" → draft del "Hola" queda stale, jamás se envía;
  solo puede salir respuesta compatible con "qué haces ahora?".
- **H15 — dos contactos simultáneos**: Emma "qué haces?" + Diego "cuánto
  vale el negro?" → Emma jamás recibe precio/producto de Diego; Diego jamás
  recibe persona/contexto de Emma.
- **H16 — cuatro contactos**: A/B/C/D casi simultáneos → los 4 turnos llegan
  a terminal state, ninguno perdido, ninguno zombie, ninguno recibe draft
  ajeno.
- **H17 — flood de un contacto**: 20 fragmentos rápidos → sin OOM, sin 20
  inferencias, sin starvation de otros contactos, sin pérdida silenciosa de
  la intención final.
- **H18 — system notification noise (P1-NOISE-01)**: teléfono cargando,
  com.android.systemui actualiza batería repetidamente → NotificationListener
  puede observarla, pero NO crea [turn], NO entra a BurstTurnGate, NO crea
  conversation state, NO toca supersede, NO draft, NO LLM, NO wake del
  runtime. WhatsApp sigue normal.
- **H19 — noise + multi-contact load**: SystemUI generando + A (4 mensajes
  rápidos) + B (3) + C (1) + D (2) → SystemUI = 0 logical turns; A/B/C/D
  aislados por conversationId, sin mezcla, sin starvation, sin stale draft,
  sin pérdida, sin zombie, sin inferencia causada por SystemUI.

### Validación física 2026-09-07 (APK R5-03..R5-06 + NOISE-01 + PROMPT-ECO-01)

Evidencia logcat real en Oppo (trazas [noise]/[route]/[reply:quality]/
[decision]):

- **H18 PASS (16:51:22)**: replay frío completo — phonemanager ×4, youtube,
  googlequicksearchbox, systemui ×2 → todos `[noise] … descartado pre-burst`,
  CERO `[turn]`. Antes (16:50:16, APK vieja): youtube solo creaba
  `[turn] conv=com.google.a`. Repetido PASS (17:02:25) + ruido VIVO
  (17:15:21 youtube, 17:19:11 clima) también descartado.
- **R5-04 LIVE STATE PASS (16:45:41)**: "Que haces" →
  `[reply:quality] liveStateRequired=true` → reply "No sabes ahora, ¿qué
  pasó?" → `[decision]` hold QUESTION MIRROR conf=0.55. Espejo retenido,
  cero invención despachada.
- **R5-PROMPT-ECO-01 (16:58:32)**: "como estas?" → reply "No sabes ahora,
  ¿qué pasó?" DESPACHADO (REMOTE_INPUT_ACCEPTED) — el 1.5B copió la frase
  LIVE STATE del prompt social. Fix: frase fuera del prompt social,
  live-state enruta a prompt completo (regla 6), regla 6 reformulada
  anti-eco.
- **R5-PROMPT-ECO-01 revalidado PASS (17:21:37)**: "como estas?" →
  "Estoy bien, gracias por preguntar." → dispatch autoSend. Saludo limpio.
- **Mixto social + live state (17:26:39)**: "me alegra y que haces?" →
  prompt completo (`liveStateRequired=true`) → reply "¿Cómo puedo ayudarte
  hoy?" → `[decision]` hold P0-NO-CALLCENTER conf=0.00. Fail-closed en
  cadena: routing correcto + guard retiene el fallo del modelo.

### Pendientes físicos (usuario)

- **H04/H08/H09 — sembrar par**: Ajustes → Agente personal → nuevo ejemplo
  con campo "Cuando el cliente escribe algo como…" (ej. incoming "cuánto
  vale el negro" + body del dueño) → WhatsApp mensaje parecido → esperar
  `[persona:retrieve] pairedCandidates=1` y traza `[persona:example]
  paired=true`; mensaje NO parecido → `pairedCandidates=0` (H09).
- **H06 — repair anclado**: tras reply de Nano, enviar "eso esta mal" →
  prompt con "Lo último que respondiste: …" y reply vinculado al anterior.
- **H07**: "te pregunte que haces ahora" → intent actividad actual,
  retención si inventa/espeja.
- **H10 — hecho pasado**: par {incoming:"dónde estás?", owner:"en el salón"}
  + "dónde estás?" al día siguiente → NO "en el salón".
- **A01 fresh install (PROD AUTONOMY FAIL-SAFE)**: `pm clear` AUTORIZADO
  diferido post-R5-02 — borra dataset Persona; sembrar pares primero.
