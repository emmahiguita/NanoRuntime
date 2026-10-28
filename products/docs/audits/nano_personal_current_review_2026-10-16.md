# Revisión de Nano personal — 16-10-2026

El texto pegado se contrastó con fuentes actuales y una prueba sintética en el teléfono. Sus afirmaciones de integración completa y comprensión completa no son evidencia de aceptación. El código actual difiere del resumen; la prueba nativa corresponde al APK instalado durante la medición, no certifica cambios fuente posteriores.

## Lo que está demostrado

- LiteRT ejecuta pesos locales reales. El teléfono seleccionó `qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm`.
- La prueba sintética de Qwen3 0.6B usó CPU, aproximadamente 545147 KiB PSS al cargar. TTFT por turno: 2832, 856 y 875 ms. Los dos últimos reutilizaron la conversación.
- La misma prueba **falló comprensión**: el interlocutor dijo que era Lucas y aprendía guitarra; corrigió su nombre a Sara. El modelo se presentó como si él fuera Lucas/Sara y en el tercer turno cambió guitarra por piano. La rapidez de KV no prueba fidelidad semántica. No se llegó al cuarto turno de conocimiento general.
- Esta prueba no leyó conversaciones privadas ni envió nada a WhatsApp. El fallo de ese paquete no prueba que todos los modelos LiteRT tengan igual calidad.
- El Qwen Omni instalado está catalogado para MNN. EmbeddingGemma Omni es otra entrada, de embeddings, no un sustituto conversacional. No se encontró evidencia que confirme el recuerdo de una antigua ruta Omni generativa por LiteRT.

## Hallazgos prioritarios

### 1. Memoria nativa reutilizada sin equivalencia exacta

`android/app/src/main/kotlin/dev/nanoai/mobile/channels/LiteRtGeneration.kt:51` permite reutilizar KV si el historial entrante es únicamente un sufijo del esperado. El contenido que se retiró del historial sigue en el KV; no se elimina por comparar listas. Además, `canonicalAssistantContent` elimina todas las alternativas después de `||` del comparador, aunque sus tokens sí estuvieron en la generación real. La nueva conversación reconstruida y la conservada pueden tener estados diferentes ante la misma historia visible.

`CURRENT_MSG_MARKER` espera `\nMensaje actual:\n`, mientras el escritor construye `Mensaje actual: $message` en una sola línea. La normalización no reconoce el formato producido y puede impedir la reutilización prometida.

**Corrección necesaria:** comparar estado realmente materializado; reconstruir ante historial divergente/recortado, respuesta rechazada o alternativa seleccionada diferente. No retirar metadatos del comparador como sustituto de retirarlos del KV.

### 2. MCP incremental aún no está activado en el flujo

`lib/features/automation/engine/mcp/whatsapp_mcp_delta_sync.dart:37` declara `syncWithCaller`. La búsqueda en `lib` encontró la declaración, pero ningún llamador. Los consumidores llaman `buildPendingSummaryBlock`, que solo lee SQLite; no invoca MCP. La existencia del coordinador y del canal Kotlin no demuestra sincronización.

**Corrección necesaria:** conectar un cliente MCP realmente configurado, con identidad de cuenta/conversación y evidencia de un lote aplicado. No declarar cobertura de WhatsApp a partir de notificaciones parciales.

### 3. La deduplicación de 30 segundos pierde mensajes legítimos

`android/app/src/main/kotlin/dev/nanoai/mobile/automation/CanonicalObservationIdentity.kt:45` compara texto y proximidad contra mensajes de proveedores autoritativos sin exigir su mismo ID ni autor en esa rama. Dos «sí» legítimos en 30 segundos pueden colapsarse. `promoteNotificationIfPresent` también selecciona la notificación por conversación, dirección, cuerpo y proximidad, sin identificar de forma inequívoca el mismo evento.

**Corrección necesaria:** IDs del proveedor o reconciliación estricta con identidad compatible; ambigüedad conserva ambos mensajes. No fusionar por texto/ventana temporal.

### 4. Agenda y otros chats se inyectan demasiado ampliamente

`lib/features/automation/engine/language/runtime_personal_live_context.dart:98` añade agenda del propietario y resumen global de pendientes para preguntas frecuentes como «qué haces». `buildPendingSummaryBlock` recibe solo un límite, sin ámbito de contacto o permiso para divulgar otros chats. Esto mete nombres y fragmentos de otras conversaciones en el prompt destinado a un contacto, y aumenta el contexto del modelo pequeño.

**Corrección necesaria:** separar asistente privado del dueño de respuestas a contactos. Recuperar únicamente contexto autorizado para ese destinatario y consulta. El riesgo se identifica en la ruta de código; no se afirma que ya se haya divulgado en un envío real.

### 5. Persisten frases fijas y una inferencia falsa de disponibilidad

`lib/features/automation/personal_agent/application/personal_conversation_resolver.dart:149` contiene listas literales de respuestas para hora, agenda y pendientes. Las horas pueden ser datos reales, pero esas opciones no son redacciones del modelo. La frase de la línea 195 transforma «sin tareas anotadas» en «tienes el día libre», cosa que la agenda vacía no demuestra.

**Corrección necesaria:** separar extracción factual de redacción real y conservar ausencia de datos como ausencia. No presentar listas prefabricadas como generación LiteRT.

### 6. Tres opciones y comprensión completa no están garantizadas

El parser admite `||`, pero eso no demuestra que siempre se hayan generado tres alternativas apropiadas. Además, el modelo Qwen3 pequeño pasa por `_capacityPersonalSystem`, que no usa la instrucción de opciones de `_nativePersonalSystem`. Una instrucción de prompt, un marco de reglas y chips en UI no prueban comprensión de párrafos o continuidad.

**Corrección necesaria:** evaluar contenido, autores, correcciones y pertinencia por modelo. Para respuesta automática se necesita una buena respuesta; las variantes manuales deben validarse individualmente y no contaminar el historial de lo realmente enviado.

### 7. El cursor puede avanzar sobre eventos no aplicados

`android/app/src/main/kotlin/dev/nanoai/mobile/automation/CanonicalMcpDeltaSync.kt:105` cuenta `upsert=false`, pero igualmente confirma la transacción y avanza el cursor. `false` puede significar duplicado o rechazo de una fila; el contrato no distingue ambos. El adaptador Dart también descarta eventos que no reconoce antes de confirmar el cursor de todo el lote. Una transacción SQL por sí sola no evita saltarse eventos.

**Corrección necesaria:** resultados tipados para aplicado/duplicado/rechazado; decidir explícitamente qué permite avanzar el cursor, con cuarentena o reintento para datos no aplicados.

## Cambios locales y verificación de esta revisión

Se conservó el estado `outboundDispatched` en la adaptación canónica y en el historial nativo con el marcador «entrega no verificada». Esto permite recordar lo que Nano despachó sin convertirlo en entrega confirmada. Los efectos desconocidos siguen fuera del diálogo. No se modificó la historia de WhatsApp ni se confirmó entrega por inferencia.

Las dos pruebas de esa adaptación y las tres de respaldo personal pasaron. El grupo actual de 15 pruebas focalizadas terminó con 14 aprobadas y una fallida: el nuevo parser admite texto de actividad inventada donde la prueba anterior esperaba rechazo inmediato. Esto demuestra un cambio de contrato del parser, **no prueba por sí solo un envío inseguro**, porque existe una decisión posterior que también debe verificarse. No corresponde afirmar que todos los checks actuales pasan.

El análisis focalizado de la adaptación canónica y su prueba quedó sin incidencias. El APK debug fullSideload compiló; esa compilación no certifica conversación natural ni entrega. No se instaló este último artefacto durante la revisión del texto pegado.

## Orden de trabajo

1. Estabilizar historia, autores y estado KV; proteger el ámbito privado del propietario.
2. Corregir identidad/deduplicación y activar MCP solo con un cliente real verificable.
3. Evaluar los paquetes LiteRT instalados con el mismo diálogo y escoger con evidencia; Qwen3 0.6B no aprobó esta prueba.
4. Validar conversación completa por WhatsApp, con corrección y cambio de tema, comprobando contenido y recepción. Después medir velocidad total y variantes de UI.

Nano ya tiene inferencia y transporte reales. Aún no hay evidencia suficiente para llamarlo conversación personal estable y natural de extremo a extremo.
