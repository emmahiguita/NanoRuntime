# Informe de ingeniería inversa — módulo de automatización NanoAI Mobile

**Fecha de corte:** 2026-09-23  
**Repositorio:** `Nanoai`  
**Revisión:** `b0cf5d42a02f0f3ee0102049dcca1f028a6db263`  
**Alcance principal:** `products/nanoMOBILE/flutter_app/lib/features/automation`  
**Alcance indispensable adicional:** integración Android/Kotlin/JNI/CMake, configuración Gradle, servicios nativos y dependencias que ejecuta el módulo.  
**Tipo de trabajo:** auditoría estática, ingeniería inversa y corrección incremental. Las correcciones se validan estáticamente; la aprobación dinámica queda a cargo del usuario.

## 1. Dictamen ejecutivo

**El módulo no puede considerarse 100 % funcional, completo ni listo para automatización desatendida.**

El analizador de Dart no encuentra errores de tipado o lint en el módulo, la arquitectura contiene defensas valiosas y la capa Android está bastante desarrollada. Sin embargo, existen fallos confirmados de seguridad funcional, verdad conversacional, identidad, memoria, envío de WhatsApp, cancelación, procesos, privacidad y representación de medios. Dos fallos son críticos:

1. Nano puede producir respuestas personales plausibles pero inventadas —por ejemplo, afirmar que ya almorzó, que está en casa o que su familia está bien— sin fuente factual.
2. La herramienta autónoma de WhatsApp puede usar un contacto genérico/primero, enviar sin confirmación y declarar “mensaje enviado” antes de comprobar el clic o la entrega real.

Por lo tanto:

- **Conversación natural:** parcial; hay variación, memoria acotada y estilo, pero también bancos estáticos, repetición posible y afirmaciones no sustentadas.
- **Comprensión:** parcial; combina reglas, contexto, modelo local y conocimiento externo, pero los clasificadores acotados dejan huecos semánticos relevantes.
- **Memoria:** parcial; conserva hasta 60 entradas por conversación y 100 conversaciones, pero solo de evidencia observada por Nano y con fallos de persistencia/identidad posibles.
- **WhatsApp:** parcial; opera sobre notificaciones, `RemoteInput`, intents y accesibilidad. No posee acceso a la base privada ni al historial íntegro de WhatsApp.
- **Ejecución autónoma segura:** no conforme por los hallazgos críticos.
- **UI móvil:** Material 3 y adaptación horizontal parcial confirmadas por código; Material Expressive, ausencia de overflow y “No Overlay” no pudieron certificarse dinámicamente.
- **Mantenibilidad solicitada:** no conforme; 126 archivos superan 200 líneas.

### Semáforo global

| Área | Estado | Motivo principal |
|---|---|---|
| Compilación estática Dart | Conforme | `flutter analyze` limpio |
| Verdad/no alucinación | Corregido estático; manual pendiente | Sin hecho vivo, la respuesta se retiene para aprobación |
| Seguridad de envíos | Corregido estático; manual pendiente | Destino/texto explícitos, confirmación y resultado no verificado |
| Identidad y chats duplicados | Corregido estático; manual pendiente | Ya no une por nombre, título ni sufijo; falta validar/migrar aliases históricos |
| Memoria conversacional | Parcial | Acotada y persistente, pero no es historial completo y puede perder escrituras |
| Procesos y cancelación | No conforme | Puente desacoplado y timeouts sin cancelación física |
| Rendimiento | No conforme | Cola global LLM y escaneo síncrono de medios |
| Android/Kotlin/JNI | Parcial alto | Buenas defensas, pero falta validación física y firma de producción |
| UI/Material/horizontal | Parcial | Código adaptativo presente; prueba física no disponible |
| SOLID/Clean Architecture | Parcial | Hay interfaces y capas, pero coordinadores monolíticos y alto fan-in |
| Límite de 200 líneas | No conforme | 126/522 archivos lo exceden |
| Certificación “100 %” | Rechazada | Hay fallos críticos y evidencia dinámica incompleta |

## 2. Evidencia y límites de la auditoría

### 2.1 Ejecutado

- Reconstrucción del grafo del módulo y rastreo de dependencias, llamadas y puntos de alto fan-in.
- Lectura dirigida de flujo conversacional, memoria, deduplicación, herramientas, política, ejecución, UI y Android.
- Inventario físico: **522 archivos, 93.113 líneas; 126 archivos con más de 200 líneas**.
- `flutter analyze lib/features/automation --no-fatal-infos`: **exit 0, “No issues found”, 31,6 s**.
- `flutter pub outdated --no-dev-dependencies`: lectura de deuda de dependencias; no se actualizó nada.
- Revisión de manifiesto, seguridad de red, Gradle, servicios, worker nativo y CMake/JNI.
- Verificación ADB: `adb devices` no devolvió ningún dispositivo.

### 2.2 No ejecutado

- No se ejecutaron pruebas automatizadas, por instrucción expresa.
- No se enviaron mensajes reales, no se activó accesibilidad y no se manipularon contactos.
- No se compiló ni instaló un APK durante esta auditoría.
- No se pudo validar en dispositivo rotación horizontal, overlays, reinicio de proceso, batería, latencia del modelo, envío real ni recuperación tras caída.

### 2.3 Significado de los estados

- **Confirmado:** deriva directamente del código actual o de una herramienta estática ejecutada.
- **Requiere validación dinámica:** el código existe, pero su resultado depende del dispositivo/OS/WhatsApp.
- **No verificable:** faltó el dispositivo, credencial, proveedor o condición externa necesaria.

Un análisis limpio no demuestra que la lógica sea correcta; solo demuestra que el código analizado satisface el compilador y las reglas configuradas.

## 3. Ingeniería inversa del flujo

### 3.1 Flujo de mensajería

```text
Notificación Android / MessagingStyle
  -> NotificationAutomationService (Kotlin)
  -> DurableInbox SQLite + EventChannel
  -> NotificationEventRouter
  -> RulePipeline
       elegibilidad -> dedupe -> BurstTurnGate -> rate limit
  -> RuleDispatcher
  -> ConversationReplyComposer
       contexto/memoria
       -> PragmaticFastPath o modelo local
       -> conocimiento externo opcional
       -> ConversationDecisionEngine
  -> AutomationCoordinator
  -> política / ownership / journal
  -> RemoteInput o accesibilidad/intent
  -> resultado + memoria + ACK
```

### 3.2 Flujo de automatización general

```text
Objetivo/orden
  -> parser + planner + proveedores de candidatos
  -> intent firewall + política semántica + critic
  -> PlanExecutionCoordinator
  -> ToolRegistry / handlers
       UI | Linux | MCP | web | WhatsApp | notificación | sistema
  -> ActionVerifier / GoalVerifier / journal
  -> resultado observable o estado desconocido
```

### 3.3 Fronteras de verdad

Nano sí puede observar y guardar:

- metadatos y texto expuestos por notificaciones Android;
- `MessagingStyle` cuando WhatsApp lo publica;
- respuestas salientes que Nano despachó u observó;
- configuración y memoria propias;
- contactos si el usuario concede permiso;
- estado visible/accesible de UI cuando accesibilidad está activa.

Nano no obtiene por este módulo:

- la base de datos privada completa de WhatsApp;
- mensajes antiguos que nunca llegaron como notificación a Nano;
- confirmación de lectura/entrega solo porque Android aceptó un `PendingIntent`;
- ubicación, actividad, comida, sueño, familia o intención actual del dueño sin otra fuente explícita;
- identidad infalible cuando WhatsApp cambia entre nombre, `@lid`, JID, shortcut y títulos.

El propio `conversation_context_resolver.dart:1-5` documenta correctamente esta frontera: combina solo evidencia observada y no lee la base privada de WhatsApp. Por eso “conectar con el historial real completo” no está implementado ni puede afirmarse solo por tener permiso de notificaciones.

## 4. Hallazgos resumidos

| ID | Severidad | Estado | Hallazgo |
|---|---|---|---|
| AUT-P0-01 | Crítica | Corregido estático; manual pendiente | Respuestas personales inventadas por fast path |
| AUT-P0-02 | Crítica | Corregido estático; manual pendiente | Envío WhatsApp sin confirmación y falso “completado” |
| AUT-P1-03 | Alta | Corregido estático; manual pendiente | Contaminación de memoria entre identidades/paquetes |
| AUT-P1-04 | Alta | Corregido estático; migración/manual pendiente | Fusión incorrecta y duplicados de conversaciones |
| AUT-P1-05 | Alta | Corregido estático; manual pendiente | “Ver una vez” puede abrir el medio equivocado |
| AUT-P1-06 | Alta | Corregido estático; manual pendiente | Puente Node desacoplado con riesgo de proceso zombi/PID reutilizado |
| AUT-P1-07 | Alta | Corregido estático; manual pendiente | Timeout lógico no cancela el efecto real |
| AUT-P1-08 | Alta | Corregido estático; manual pendiente | Cola LLM global causa bloqueo y trabajo obsoleto |
| AUT-P1-09 | Alta | Corregido estático; manual pendiente | Escrituras de memoria no esperadas y fallos silenciados |
| AUT-P1-10 | Alta | Corregido estático; manual pendiente | Texto privado puede salir a proveedores web y logs |
| AUT-P2-11 | Media | Confirmado | Repetición y lenguaje estático tras reinicios |
| AUT-P2-12 | Media | Confirmado | I/O síncrono y escaneo recursivo desde flujo de UI |
| AUT-P2-13 | Media | Confirmado | Incumplimiento estructural de 200 líneas/SRP |
| AUT-P1-14 | Alta | Corregido estático; manual pendiente | Release puede firmarse con clave debug |
| AUT-P2-15 | Media | Confirmado | Carrera de cierre y admisión del router de notificaciones |
| AUT-P2-16 | Media | Confirmado | Deuda de framework y dependencias, incluida una anulación antigua |

## 5. Hallazgos detallados

### AUT-P0-01 — Respuestas personales inventadas

- **Categoría:** comprensión, coherencia, naturalidad, no alucinación.
- **Archivo/rango:** `engine/language/pragmatic_fast_path_situation_banks.dart:14-180`; `pragmatic_fast_path_activity_banks.dart:14-99`; `pragmatic_fast_path_dialogue_banks.dart:14-152`; `pragmatic_fast_path.dart:165-193`; `personal_agent/domain/conversation_agent_role.dart:560-600`; `conversation_decision_engine.dart:274-345`.
- **Evidencia:** los bancos contienen afirmaciones como “Sí, ya almorcé”, “Aquí en la casa”, “Todo bien con la familia”, “ya casi me voy a dormir”, “escuchando rap” y “trabajando”. El fast path devuelve `missingFacts: []` y `requiresAction: false`. El guard de estado vivo reconoce sobre todo actividad/ubicación y no cubre de forma exhaustiva comida, familia, sueño, música, disponibilidad u opinión.
- **Problema:** el sistema confunde naturalidad con certeza factual.
- **Impacto:** Nano puede mentir en nombre del usuario y enviar la mentira automáticamente.
- **Severidad/confianza:** crítica / alta.
- **Reproducción manual:** activar bot en un chat seguro y preguntar “¿ya almorzaste?”, “¿cómo está tu familia?”, “¿qué música escuchas?” o “¿te vas a dormir?”. Registrar si se envía una afirmación sin dato vivo.
- **Solución recomendada:** contrato de fuente factual por intención; separar estilo aprendido de hechos; ampliar clasificación de estado vivo; si no existe fuente, responder con incertidumbre honesta o retener para aprobación.
- **Riesgo de corregir:** medio; una restricción excesiva puede volver robótica la conversación. Debe conservar tono, pero no fabricar hechos.
- **Corrección aplicada:** guard central de hechos vivos; las intenciones personales sin fuente pasan a aprobación humana y se retiraron reparaciones que afirmaban estados inventados.

### AUT-P0-02 — WhatsApp puede enviar al contacto incorrecto y reportar éxito antes de tiempo

- **Categoría:** seguridad, mensajería, ejecución, gobernanza.
- **Archivo/rango:** `engine/governance/semantic_policy.dart:140-149`; `engine/execution/tool_registry.dart:225-243,524-592`; `handlers/whatsapp_tool_handler.dart:34-106`; `android/.../ShareChannelHandler.kt:113-151`; `AgentAccessibilityService.kt:819-893`.
- **Evidencia:** `whatsapp.send_message` y `share_file` se clasifican como escritura reversible sin confirmación. Un destinatario vacío/genérico devuelve `all.first`. Texto vacío se convierte en “Hola desde NanoAI”. El handler usa `autoSend: true`. Kotlin devuelve `result.success(true)` tras abrir/armar la operación, mientras el clic se intenta después durante hasta 5 s.
- **Problema:** lanzamiento de WhatsApp, clic y entrega se tratan como la misma cosa.
- **Impacto:** envío no autorizado o al contacto equivocado; auditoría falsa; imposible garantizar exactamente una vez.
- **Severidad/confianza:** crítica / alta.
- **Reproducción manual:** invocar la herramienta con `contacto`, `destinatario` o texto vacío; observar el contacto elegido y comparar el resultado retornado con el clic real.
- **Solución recomendada:** marcar envío como commit irreversible; confirmación obligatoria; ID exacto de contacto; prohibir fallback al primero y texto por defecto; estados `launched/armed/clicked/observed/unknown`; journal previo y verificación posterior.
- **Riesgo de corregir:** medio; cambia UX y contratos de resultado, pero es necesario.
- **Corrección aplicada:** riesgo irreversible y confirmación obligatoria; destinatario y texto explícitos; sin fallback al primer contacto; apertura de chat sin autoenvío; envío explícito reportado como no verificado.

### AUT-P1-03 — Contaminación cruzada de memoria conversacional

- **Categoría:** memoria, identidad, privacidad.
- **Archivo/rango:** `engine/messaging/conversation_context_resolver.dart:33-47,79-82`.
- **Evidencia:** el resolver recorre todos los IDs conocidos; puede unir por huella o por nombre del remitente. Para IDs históricos sin `/`, `_samePackage` devuelve `true`.
- **Problema:** un ID legado de otra plataforma o una persona homónima puede incorporarse al contexto actual.
- **Impacto:** respuesta incoherente y posible exposición de contenido de otro chat/persona.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** crear memorias legadas con el mismo nombre en dos plataformas y abrir el chat de WhatsApp correspondiente.
- **Solución recomendada:** tabla persistente de aliases validada por puente fuerte; exigir paquete/cuenta; no unir por nombre solo; migración explícita para IDs antiguos.
- **Riesgo de corregir:** medio; puede reintroducir duplicados hasta migrar aliases reales.
- **Corrección aplicada:** memoria cruzada solo con IDs técnicos fuertes del mismo paquete y cuenta; nombre e ID legado sin ámbito dejaron de ser puentes.

### AUT-P1-04 — Chats duplicados o fusionados indebidamente

- **Categoría:** UI, identidad, deduplicación, rendimiento.
- **Archivo/rango:** `presentation/messaging_center/messaging_conversation_identity.dart:82-147`; `messaging_dedup_merger.dart:142-163`.
- **Evidencia:** se unen teléfonos por igualdad o sufijo y nombres iguales cuando hay puente vivo o alguno de los IDs es débil. Dos contactos homónimos débiles pueden colapsar; aliases fuertes sin puente observable pueden seguir duplicados. El merger reinicia el recorrido tras cada unión.
- **Problema:** la equivalencia se infiere con señales ambiguas; el algoritmo puede aproximarse a O(n³) en cadenas de aliases.
- **Impacto:** conversaciones mezcladas, chats faltantes o duplicados; riesgo de responder al historial equivocado.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** dos “Juan” con IDs débiles; números con sufijo común; abrir sin notificación activa un chat que alternó nombre y `@lid`.
- **Solución recomendada:** union-find/índice por paquete-cuenta; aliases persistentes solo con evidencia fuerte (JID/shortcut/evento observado); nombre solo como etiqueta, nunca como identidad.
- **Riesgo de corregir:** medio-alto por migración de datos existentes.
- **Corrección aplicada:** se eliminaron equivalencias por nombre, título, mensaje coincidente y sufijo telefónico; la agrupación usa union-find O(n²) y conserva solo aliases demostrados. Los aliases históricos débiles no se migran automáticamente.

### AUT-P1-05 — “Ver una vez” puede mostrar un archivo ajeno al mensaje

- **Categoría:** componente sin lógica real, privacidad, medios, coherencia visual.
- **Archivo/rango:** `presentation/widgets/view_once_media_card.dart:1-13,27-31,153-172`; `whatsapp_media_resolver.dart:107-160`; `parsed_media_message.dart:135-177`; `NotificationAutomationService.kt:322-379`.
- **Evidencia:** la tarjeta afirma que Nano “rescata” el contenido. Si no hay ruta, al tocar busca el archivo más reciente de WhatsApp. El resolver escanea directorios y usa cercanía de fecha o el archivo más reciente; no demuestra que pertenezca a esa notificación. Para “ver una vez” Android puede publicar solo la etiqueta, sin archivo.
- **Problema:** el fallback sustituye evidencia ausente por un archivo probable.
- **Impacto:** se muestra una foto/video incorrecto y potencialmente privado.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** recibir una foto normal, después una notificación “ver una vez” sin ruta, y pulsar la tarjeta.
- **Solución recomendada:** no abrir nada sin URI/ruta capturada y correlacionada con evento; mostrar “medio no disponible”; eliminar afirmaciones de preservación no demostradas.
- **Riesgo de corregir:** bajo; reduce una función aparente, pero recupera honestidad.
- **Corrección aplicada:** la tarjeta consulta asíncronamente la ruta exacta, deshabilita la acción si falta y ya no busca el medio reciente ni afirma preservación.

### AUT-P1-06 — Puente desacoplado con riesgo de zombi y PID reutilizado

- **Categoría:** procesos zombi, Linux/Node, ciclo de vida.
- **Archivo/rango:** `engine/browser/reverse_agent_client.dart:70-141`.
- **Evidencia:** `Process.start(... ProcessStartMode.detached)` guarda PID de forma síncrona; mata el PID previo con `SIGKILL` sin validar identidad. `stopBridge()` no tiene llamadores en el grafo ni en búsqueda de referencias.
- **Problema:** el proceso no tiene propietario de ciclo de vida fiable; un PID obsoleto puede pertenecer a otro proceso.
- **Impacto:** procesos huérfanos, consumo permanente o terminación equivocada.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** iniciar puente, cerrar proceso Flutter, comprobar PID; corromper/reutilizar archivo PID y reiniciar.
- **Solución recomendada:** servicio supervisado o grupo de procesos; token de inicio/cmdline; archivo PID atómico; cierre invocado y esperado; health/exit explícitos.
- **Riesgo de corregir:** medio por coordinación Android/Linux.

### AUT-P1-07 — El timeout no cancela la operación física

- **Categoría:** timeouts, ejecución, recursos.
- **Archivo/rango:** `engine/execution/agent_tool_dispatcher.dart:560-595`.
- **Evidencia:** `.timeout(...)` devuelve `[timeoutOutcomeUnknown]`; el propio código reconoce que la operación puede continuar. El token de cancelación no termina necesariamente `_executeTool` ni su proceso nativo.
- **Problema:** se cancela la espera, no el efecto.
- **Impacto:** acciones tardías después de que UI declara timeout, recursos ocupados y retries peligrosos.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** ejecutar comando largo, forzar timeout y comprobar proceso/efecto posterior.
- **Solución recomendada:** ejecutores cancelables; kill por grupo/tarea; esperar confirmación de terminación; estado `unknown` bloquea retry automático.
- **Riesgo de corregir:** medio-alto; algunos backends no admiten cancelación inmediata.

### AUT-P1-08 — Cola global LLM con bloqueo de cabecera

- **Categoría:** cuello de botella, concurrencia, latencia.
- **Archivo/rango:** `engine/notifications/notification_draft_writer.dart:150-210,219-229`; `lib/core/services/llm_engine_client.dart:26-35,173-186`.
- **Evidencia:** `_draftTail` serializa globalmente hasta 64 borradores. `ensureReady` permite 60 s y la generación local 240 s. La sesión por turno del writer contradice el comentario “sesión estable por conversación” del cliente.
- **Problema:** un turno lento bloquea todos los chats y los pedidos obsoletos siguen consumiendo cola/modelo.
- **Impacto:** respuestas de minutos u horas tarde en el peor caso; memoria/estado ya cambiaron cuando llega el borrador.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** provocar generación lenta en un chat y enviar mensajes en varios chats; medir cola y edad al enviar.
- **Solución recomendada:** coalescer por conversación, deadline de frescura, cancelación previa a generación, prioridad y descarte de superseded; mantener una sola inferencia si el motor lo exige, no 64 esperas ciegas.
- **Riesgo de corregir:** medio.

### AUT-P1-09 — Persistencia de memoria “best effort” sin salud durable

- **Categoría:** memoria, SQLite, consistencia.
- **Archivo/rango:** `engine/messaging/conversation_memory.dart:206-212,710-760`; `engine/storage/automation_db_store_client.dart:104-153`.
- **Evidencia:** `_markDirty`, append normalizado y estado usan `unawaited`. El cliente atrapa errores y retorna `false`; esos resultados no gobiernan la memoria en RAM.
- **Problema:** la aplicación puede creer que aprendió/guardó algo que se perderá al reiniciar.
- **Impacto:** repetición, chats redivididos, obligaciones olvidadas e incoherencia tras caída.
- **Severidad/confianza:** alta / alta.
- **Reproducción manual:** llenar/denegar almacenamiento o inducir error del canal, conversar y reiniciar.
- **Solución recomendada:** cola serial de escrituras confirmadas, dirty retry/backoff, health observable y degradación segura cuando persistencia está enferma.
- **Riesgo de corregir:** medio por migración y backpressure.

### AUT-P1-10 — Mensajes privados pueden salir a web y a logs

- **Categoría:** privacidad, seguridad, proveedores externos.
- **Archivo/rango:** `engine/conversation/turn_knowledge_router.dart:99-167`; `engine/notifications/notification_draft_writer.dart:176-190,235-239,443-475`.
- **Evidencia:** palabras clave disparan envío del texto a Browser AI, puente ChatGPT o búsqueda web; se imprime el texto de consulta y muestras de entrada/salida. No se observó en este router una política de redacción por chat ni consentimiento por mensaje.
- **Problema:** una pregunta privada con patrón de conocimiento puede abandonar el dispositivo.
- **Impacto:** exposición a proveedores y logcat.
- **Severidad/confianza:** alta / alta sobre el código; activación real depende de configuración.
- **Reproducción manual:** configurar proveedor, enviar texto con dato personal más palabra clave y observar tráfico/logcat.
- **Solución recomendada:** privacidad local por defecto; consentimiento; consulta mínima desidentificada; redacción; logs release sin cuerpo; indicador visible del proveedor.
- **Riesgo de corregir:** medio; puede reducir respuestas con conocimiento actual.

### AUT-P2-11 — La variación no evita repetición semántica

- **Categoría:** aprendizaje, escritura natural, repetición.
- **Archivo/rango:** `engine/language/candidate_selector.dart:17-45`; `persona_style_resolver.dart:49-137`; bancos `pragmatic_fast_path_*_banks.dart`.
- **Evidencia:** el selector evita principalmente el último texto exacto y usa hash temporal; la rotación de estilo vive en memoria y se reinicia con el proceso. No existe historial durable de huellas semánticas por intención.
- **Problema:** Nano puede alternar dos frases equivalentes o repetir después de reiniciar.
- **Impacto:** sensación robótica y aprendizaje aparente, no real.
- **Severidad/confianza:** media / alta.
- **Reproducción manual:** repetir la misma pregunta varias veces, reiniciar app y repetir.
- **Solución recomendada:** huellas durables recientes por intención/contacto, similitud semántica, penalización de repetición y estilo separado de hechos.
- **Riesgo de corregir:** bajo-medio.

### AUT-P2-12 — I/O síncrono en rutas de interfaz

- **Categoría:** rendimiento, UI, almacenamiento.
- **Archivo/rango:** `presentation/widgets/whatsapp_media_resolver.dart:107-158`; `conversation_media_cards.dart:45`; `conversation_photo_viewer.dart:55,103`; `view_once_media_card.dart:31`; `engine/browser/reverse_agent_client.dart:83-138`.
- **Evidencia:** `existsSync`, `listSync(recursive: true)` y `statSync` se ejecutan dentro de futures/constructores que continúan en el isolate de UI; declarar una función `async` no mueve el trabajo a otro isolate.
- **Problema:** recorrer carpetas de notas de voz y ordenar/stat de muchos archivos puede congelar frames.
- **Impacto:** jank, ANR perceptible y mal comportamiento horizontal/overlay bajo carga.
- **Severidad/confianza:** media / alta.
- **Reproducción manual:** carpeta de WhatsApp grande, abrir conversación con audio/foto y medir frames.
- **Solución recomendada:** MediaStore/SAF indexado, isolate o canal nativo, consulta acotada y caché invalidable.
- **Riesgo de corregir:** medio.

### AUT-P2-13 — Incumplimiento del límite y SRP

- **Categoría:** SOLID, Clean Architecture, mantenibilidad, comentarios.
- **Archivo/rango:** módulo completo; detalle en `FILES-OVER-200.md`.
- **Evidencia:** 522 archivos/93.113 líneas; 126 archivos >200. Máximos: `automation_coordinator.dart` 883, `agent_dependencies.dart` 861, `rule_pipeline.dart` 852. El grafo marca puntos de alto fan-in como `MobileVisualResourcePolicy.state` (135), `RuntimeNotificationDraftWriter.call` (102) y `NanoRecorder.raw` (94).
- **Problema:** coordinadores mezclan orquestación, estado, policy, persistencia y presentación; el cambio tiene gran radio.
- **Impacto:** regresiones, difícil revisión y contradicciones de comentarios/contratos.
- **Severidad/confianza:** media / alta.
- **Reproducción:** conteo incluido en apéndice.
- **Solución recomendada:** extracción por responsabilidad con contratos existentes; no reescritura masiva. Objetivo incremental <200 solo para código tocado y hotspots prioritarios.
- **Riesgo de corregir:** alto si se hace en bloque. Requiere refactor por estrangulamiento.

Comentarios: 517/519 archivos Dart revisados contienen alguna forma de comentario. Los dos sin sintaxis de comentario fueron `personal_agent/domain/personal_memory.dart` y `presentation/widgets/conversation_list_tile.dart`. Cantidad no implica exactitud: hay comentarios materialmente engañosos en “ver una vez” y en la sesión LLM.

### AUT-P1-14 — Firma release con fallback a debug

- **Categoría:** distribución, seguridad Android.
- **Archivo/rango:** `android/app/build.gradle.kts:69-106`.
- **Evidencia:** si faltan variables del keystore, el build release utiliza la configuración debug.
- **Problema:** un artefacto llamado release puede no tener identidad de producción.
- **Impacto:** publicación imposible/incorrecta, cadena de suministro débil y falsas garantías.
- **Severidad/confianza:** alta / alta para distribución; no afecta sideload de desarrollo.
- **Reproducción manual:** construir release sin variables y comprobar certificado.
- **Solución recomendada:** fallar el build release si no existe keystore; variante explícita `internalSideload` para desarrollo.
- **Riesgo de corregir:** bajo; exige configurar CI/secretos.

### AUT-P2-15 — Carrera de apagado/admisión en router de notificaciones

- **Categoría:** concurrencia, lifecycle, DurableInbox.
- **Archivo/rango:** `engine/scheduling/notification_event_router.dart:30-40,103-128`; `android/.../DurableInbox.kt:55-105,174`.
- **Evidencia:** callbacks y replay disparan trabajo no esperado; `stop()` no espera `cancel()` ni drena tareas. Un evento ya reservado puede quedar hasta reclaim si no entra a capacidad.
- **Problema:** trabajo puede continuar después de desmontar el router.
- **Impacto:** duplicados tardíos, reserva temporal y shutdown no determinista.
- **Severidad/confianza:** media / alta.
- **Reproducción manual:** iniciar replay con backlog, detener runtime inmediatamente y observar ACK/reservas.
- **Solución recomendada:** `Future<void> stop`, token de generación para todo callback, drain/cancel de in-flight y claim limitado a capacidad.
- **Riesgo de corregir:** medio.

### AUT-P2-16 — Deuda de dependencias y framework

- **Categoría:** versiones, compatibilidad, mantenimiento.
- **Archivo/rango:** `pubspec.yaml`, `pubspec.lock`, `android/settings.gradle.kts`.
- **Evidencia local:** Flutter 3.38.4/Dart 3.10.3; Kotlin 2.2.20; `shared_preferences` 2.3.2; override `shared_preferences_android` 2.2.4. `flutter pub outdated` encontró 10 dependencias directas restringidas por debajo de una versión resoluble y el Android implementation está fijado a 2.2.4 frente a 2.4.28.
- **Evidencia oficial:** Flutter 3.47 fue publicado el 12-ago-2026 ([Flutter](https://docs.flutter.dev/release/whats-new)); Kotlin documenta versiones posteriores a 2.2.20 ([Kotlin](https://kotlinlang.org/docs/releases.html)); `shared_preferences` estable es 2.5.5 ([pub.dev](https://pub.dev/packages/shared_preferences/versions)).
- **Contrapeso:** AGP 8.11.1 + Gradle 8.14 + JDK 17 + compile/target 36 sí están dentro de la matriz oficial de AGP 8.11 ([Android Developers](https://developer.android.com/build/releases/agp-8-11-0-release-notes)).
- **Problema:** el override antiguo conserva un workaround de `ClassNotFoundException`; actualizar a ciegas puede reabrirlo, pero dejarlo fija deuda y correcciones pendientes.
- **Impacto:** compatibilidad futura, bugs ya corregidos y bloqueo de upgrades.
- **Severidad/confianza:** media / alta.
- **Reproducción/validación:** rama aislada, upgrade incremental y build/arranque por versión; no se hizo en esta auditoría.
- **Solución recomendada:** matriz de upgrades, comenzando por quitar el override solo tras reproducir y resolver la causa raíz.
- **Riesgo de corregir:** medio-alto.

## 6. Revisión A–Z

| Letra | Área | Resultado |
|---|---|---|
| A | Arquitectura | Capas e interfaces presentes; coordinadores demasiado grandes |
| B | Background | DurableInbox y runtime existen; lifecycle no certificado en dispositivo |
| C | Concurrencia | Colas acotadas, pero hay bloqueo global y teardown no esperado |
| D | Datos | SQLite y snapshots; persistencia best-effort puede perder estado |
| E | Ejecución | Planner/verifier/journal sólidos en partes; timeout no cancela efecto |
| F | Flutter | Analizador limpio; 126 archivos incumplen tamaño |
| G | Gradle | Matriz AGP/Gradle/JDK/API compatible; firma release insegura |
| H | Historial | Solo notificaciones observadas, no historial privado completo |
| I | Identidad | JID/shortcut/locus soportados; heurísticas de nombre aún peligrosas |
| J | JNI/CMake | C17, warnings y separación de librerías presentes; sin prueba nativa actual |
| K | Kotlin | Servicios y supervisión razonables; versión con deuda de actualización |
| L | Linux/procesos | Worker tiene kill por tarea; puente Node detached no tiene ownership fiable |
| M | Mensajería | RemoteInput/accesibilidad presentes; éxito de envío no es verificable |
| N | Naturalidad/NLU | Buena cobertura de frases; bancos estáticos inventan estado |
| O | Overlays | Uso de guardas y layouts; “No Overlay” no certificado físicamente |
| P | Permisos | Servicios sensibles protegidos; permisos amplios requieren prueba/UX clara |
| Q | Queues | Límites existen; cola LLM 64 y DurableInbox pueden acumular obsoletos |
| R | Reliability | Dedupe/journal/watchdog ayudan; estados unknown y escrituras silenciadas persisten |
| S | Seguridad/SOLID | HTTPS por defecto y componentes no exportados; P0/P1 impiden aprobación |
| T | Timeouts | Existen límites; no equivalen a cancelación real |
| U | UI/UX | Inter, Material 3, SafeArea/LayoutBuilder; Expressive no demostrable |
| V | Versiones | AGP compatible; Flutter/Kotlin/paquetes con deuda |
| W | WhatsApp | Integración extensa; no hay acceso al historial privado completo |
| X | eXternos/web/MCP | Integración funcional por diseño; falta frontera de privacidad más estricta |
| Y | Yield/recursos | Riesgo de jank y procesos tardíos; medición física pendiente |
| Z | Zombies | Worker nativo tiene limpieza; puente Node presenta riesgo confirmado |

## 7. UI móvil, Material y horizontal

### Confirmado por código

- `lib/core/theme/app_theme.dart` usa `useMaterial3: true`.
- El módulo aplica Inter y fallbacks Roboto/SF en la conversación.
- Hay `SafeArea`, `LayoutBuilder`, `MediaQuery.orientation` y variantes compactas en onboarding, reglas, inbox, detalle y compositor.
- `conversation_detail_*` reduce anchos/tamaños en landscape.
- Overlays usan comprobaciones de contexto y componentes modulares en varios puntos.

### No confirmado

- “Material Expressive 3” no es una capacidad verificable solo porque `useMaterial3` sea true. Hay una estética propia, no evidencia de adopción completa de un sistema Expressive concreto.
- Sin dispositivo no se puede afirmar ausencia de cajas rojas/amarillas, overflow, teclado tapando el compositor, overlay inválido o clipping con escalado de fuente.
- Existen pantallas de 500–800 líneas cuya adaptación debe validarse individualmente.

## 8. Android, permisos y nativo

### Fortalezas

- `allowBackup=false`.
- Tráfico HTTP bloqueado por defecto; excepciones declaradas.
- Servicio de accesibilidad exportado con `BIND_ACCESSIBILITY_SERVICE`.
- Notification listener exportado con `BIND_NOTIFICATION_LISTENER_SERVICE`.
- Runtime, overlay y worker no exportados.
- Runtime service usa `START_NOT_STICKY`, foreground y watchdog.
- Worker `:nanoshell` tiene capacidad, kill por tarea y terminación de proceso.
- CMake compila C17 con `-Wall -Wextra`; separación `nanoshell`/`nanoroot`.

### Riesgos/limitaciones

- Permisos sensibles: contactos, notificaciones, medios, micrófono, overlay y accesibilidad. Su presencia no prueba consentimiento contextual correcto.
- ABI limitada a `arm64-v8a`.
- Cleartext permitido para `wttr.in`; debe justificarse o migrarse a HTTPS.
- No se ejecutó sanitizador, análisis nativo ni prueba de fugas/FD/PTTY.
- Comentarios de CMake muestran mojibake, señal menor de mantenimiento/documentación.

## 9. Fortalezas funcionales reales

La auditoría no concluye que todo esté roto. Se confirmaron decisiones correctas:

- inbox durable antes de entrar a Dart;
- dedupe por evento y burst gate;
- límites de memoria y colas;
- ownership humano y asignación de agente;
- journal para varias acciones irreversibles;
- verificadores y estados `unknown` en parte del runtime;
- política HTTPS por defecto;
- protección Android de servicios sensibles;
- separación de contratos/interfaz en memoria, herramientas, MCP y ejecución;
- comentarios en la gran mayoría de archivos;
- layout adaptativo explícito en pantallas centrales;
- analizador Dart completamente limpio en el alcance.

Estas fortalezas reducen riesgo, pero no compensan los hallazgos críticos.

## 10. Plan de corrección y estado

Los puntos 1–5 tienen corrección estática aplicada. Requieren la matriz manual de la sección 11; los aliases débiles ya almacenados requieren una migración explícita y no se fusionan por intuición.

### P0 — bloquear antes de automatización desatendida

1. **Corregido estático:** impedir afirmaciones de estado personal sin fuente factual.
2. **Corregido estático:** hacer `whatsapp.send_message/share_file` irreversibles y confirmados; el resultado queda como no verificado hasta observación real.
3. **Corregido estático:** eliminar contacto “primero” y mensaje por defecto.
4. **Corregido estático:** desactivar fallback de “ver una vez” al archivo más reciente.
5. **Corregido estático:** impedir fusión de memoria por nombre/ID legado sin paquete/cuenta.

### P1 — integridad y disponibilidad

6. **Corregido estático:** Cola durable/confirmada para memoria y health observable de almacenamiento (`ConversationMemoryStore` y `AutomationDbStoreClient`).
7. **Corregido estático:** Cancelación física de procesos/herramientas en timeouts y validación de cmdline en puente Node (`ReverseAgentClient` y `AgentToolDispatcher`).
8. **Corregido estático:** Coalescing por conversación y deadline de frescura de 45s en cola de borradores LLM (`NotificationDraftWriter`).
9. **Corregido estático:** Alias persistente de conversaciones con evidencia fuerte (union-find en `messaging_dedup_merger.dart`).
10. **Corregido estático:** Política de privacidad y redacción de PII antes de proveedores externos y logs en release (`TurnKnowledgeRouter` y `NotificationDraftWriter`).
11. **Corregido estático:** Fallar release sin keystore de producción a menos que se autorice explícitamente en desarrollo (`build.gradle.kts`).

### P2 — mantenibilidad y UX

12. Extraer hotspots >200 líneas por responsabilidad, uno por uno.
13. Reemplazar I/O síncrono de medios por índice/MediaStore/isolate.
14. Persistir historial antirrepetición por intención/contacto.
15. Alinear comentarios con contratos reales.
16. Actualizar dependencias incrementalmente con build y prueba física.
17. Auditoría visual portrait/landscape, teclado, text scale y overlays.

## 11. Matriz de validación manual necesaria

| Caso | Evidencia de aprobación requerida |
|---|---|
| Saludo corto/largo | respuesta coherente, no eco, no frase fija repetida |
| Pregunta de estado personal | hecho con fuente o incertidumbre honesta |
| Misma pregunta repetida | variación semántica sin inventar |
| Link repetido | link no duplicado y respuesta conectada al historial |
| Dos contactos homónimos | historiales y respuestas nunca se mezclan |
| Cambio nombre ↔ `@lid` | un solo chat, alias justificable |
| Grupo vs contacto | aislamiento total de memoria |
| Envío WhatsApp | contacto exacto, confirmación, clic observado, resultado honesto |
| WhatsApp cerrado/bloqueado | no declarar enviado; estado unknown/failure |
| Reinicio durante draft | no envío tardío ni duplicado |
| Falla de SQLite | health visible, retry y memoria no fingida |
| 64 eventos en ráfaga | descarte/coalescing documentado y sin respuesta obsoleta |
| Timeout Linux/UI | proceso/acción realmente cancelado o estado unknown sin retry |
| Cierre de app | sin Node, worker, TTS, listeners o overlays huérfanos |
| Ver una vez sin URI | “no disponible”; nunca otro archivo |
| Carpeta WhatsApp grande | sin jank/ANR |
| Portrait/landscape | sin overflow, teclado usable, controles pequeños y legibles |
| Text scale 1.0/1.5/2.0 | sin cajas rojas/amarillas |
| Android 8, 13, 15/16 | permisos, FGS, notificaciones y almacenamiento correctos |
| Sin red/proveedor | degradación local honesta y privada |

## 12. Criterios mínimos para declarar “100 % funcional”

No existe una prueba única de “100 %”. Para una aprobación razonable deben cumplirse simultáneamente:

- cero P0/P1 abiertos;
- análisis y build release reproducibles;
- firma de producción obligatoria;
- matriz manual anterior completada con evidencia;
- pruebas físicas en al menos tres APIs Android y dos tamaños/orientaciones;
- exactamente una respuesta por evento, sin contaminación de identidad;
- ninguna afirmación personal sin fuente;
- cancelación y cierre sin procesos/FD/overlays huérfanos;
- política de privacidad explícita para web, logs, contactos y medios;
- recuperación demostrada ante caída de motor, SQLite, WhatsApp y proceso;
- deuda de archivos >200 reducida mediante refactor seguro, no reescritura intuitiva.

## 13. Conclusión

El módulo es amplio y tiene una base real: no es una simulación. Integra Android, memoria, reglas, LLM local, herramientas, verificación y UI. También contiene varias defensas maduras. Aun así, el comportamiento actual no satisface las condiciones pedidas de verdad, coherencia, no repetición, seguridad de mensajería, ausencia de zombis y mantenibilidad.

La prioridad no debe ser agregar más funciones. Debe ser cerrar primero las fronteras de verdad e identidad, hacer verificable el envío, corregir persistencia/cancelación y retirar los fallbacks que sustituyen datos ausentes por datos probables. Solo después tiene sentido ampliar aprendizaje o automatización.

## Apéndices

- [Inventario completo de archivos mayores a 200 líneas](FILES-OVER-200.md)
- Fuente oficial Flutter: [releases 2026](https://docs.flutter.dev/release/whats-new)
- Fuente oficial Android: [AGP 8.11](https://developer.android.com/build/releases/agp-8-11-0-release-notes)
- Fuente oficial Kotlin: [releases](https://kotlinlang.org/docs/releases.html)
- Fuente oficial de paquetes Flutter: [`shared_preferences`](https://pub.dev/packages/shared_preferences/versions)
