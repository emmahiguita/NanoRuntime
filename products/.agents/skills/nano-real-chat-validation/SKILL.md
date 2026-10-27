---
name: nano-real-chat-validation
description: Revisa el catálogo de modelos y las rutas reales de respuesta local en Nano Mobile, con límites explícitos de capacidad y ciclo de vida.
---

# Validar catálogo y respuestas locales

Usa esta guía cuando se cambien modelos, motores, chat, descargas o controles del catálogo.

## Flujo

1. Lee `AGENTS.md` y consulta primero Graphify/codebase-memory para encontrar catálogo, selección, router, adaptadores y descarte del motor. Usa búsqueda textual solo para etiquetas, configuraciones y callbacks.
2. Sigue un modelo desde su metadato (`ModelBackendType`) hasta `RuntimeEngineNotifier`, el adaptador nativo y el receptor de tokens. La extensión no basta para decidir el motor.
   - Para respuestas repetidas o fuera de tono, sigue también `temperature`, `topP` y penalización de repetición desde ajustes/chat hasta el `set_config` del runtime; que la UI tenga sliders no demuestra que el motor los reciba.
3. Compara lo que anuncia la UI con el perfil cargado realmente. Si el paquete activo es de texto, rechaza imagen/audio en la frontera; no insertes rutas o nombres de archivo como si fueran multimedia procesada.
4. Sigue cada acción visible hasta su callback, y verifica que estados de progreso, cancelación, instalación y borrado dependan del resultado real. Un borrado debe detener y liberar el modelo antes de eliminar su archivo; si falla, no marques el modelo como desinstalado.
5. Revisa cancelación, timeout, un solo motor activo, reintentos y salida de pantalla. Evita trabajos periódicos sin dueño y libera las suscripciones/recursos al cerrar.
6. Busca evidencia de versiones, hashes y artefactos del catálogo. Reporta soporte, capacidades y rendimiento únicamente cuando estén demostrados para esa combinación runtime/paquete/dispositivo.
7. Ejecuta análisis estático y compilación Android de la variante afectada. No corras pruebas automatizadas si el usuario pidió validación manual; deja claro qué flujo físico requiere su revisión.
8. No declares el sistema “100% funcional” con análisis o compilación solamente. Separa rutas compiladas, medidas reales y capacidades pendientes de ejecutar en dispositivo.

## Cambios

- Identidad y agenda comparten ownerProfile: serializa parches y conserva las
  claves ajenas. Si falla la lectura, no sobrescribas con un perfil vacío.
- La agenda libre es declaración del usuario, no actividad observada: exige
  autorización, fecha local vigente y no infieras huecos libres ni ubicación.
- Frases personales son ejemplos de estilo para inferencia, no respuestas
  literales automáticas. Refleja fallos reales de persistencia en crear/editar/borrar.
- El motor headless debe releer los datos personales editados antes del prompt;
  refrescar solo el provider de la pantalla deja al agente con memoria antigua.

- Corrige el fallo en la capa responsable más pequeña y añade comentarios breves junto a lógica de ciclo de vida o límites de capacidad.
- No reemplaces el catálogo, runtime, modelo o perfil existente por una suposición de rendimiento.
- Mantén el límite del proyecto de menos de 200 líneas por archivo nuevo; si un archivo existente lo excede, evita inflarlo y extrae responsabilidades solo cuando el cambio lo requiera.
- Después de editar, ejecuta `graphify update .` desde el repositorio raíz.
- Si el LLM responde de forma irrelevante a un saludo, inspecciona sesión, historial y salida real. Cuando el usuario prohíba frases fijas, no reintroduzcas bancos de saludos ni ejemplos literales como fallback; un saludo dentro de un chat no borra su contexto.
- La aceptación por RemoteInput no valida comprensión. Contrasta respuesta y
  mensaje real; un emoji o puntuación no debe ocultar un eco literal.
- Usa la misma política textual al generar, decidir envío y recuperar contexto.
  Omite ecos/bucles del prompt sin borrar su evidencia del historial visible.
- Una regeneración por calidad debe ser acotada y pasar todas las guardas;
  nunca convierte texto recuperado en permiso ni rellena hechos faltantes.
- Si aparece `burst-shadow` con StateError, comprueba primero que la sección
  Dart `burst_shadow_v1` esté admitida por `AutomationStoreDb.VALID_SECTIONS`.
- Las sugerencias manuales no deben consumir la deduplicación de eventos automáticos ni registrar un envío/turno nuevo. Conserva el texto que el usuario ya escribe y muestra solo variantes realmente producidas por el modelo.
- Sigue también los adaptadores intermedios: `conversationReplyComposerProvider` puede devolver `ToolRoutedConversationReplyComposer`, no el compositor canónico. La vista previa debe llegar a `composeSuggestions` a través del ToolRouter, y un contexto ausente debe seguir siendo null para resolver la asignación real, no convertirse en Personal por defecto.
- Recuperar el reply de un JSON incompleto no recupera sus permisos ni obligaciones: exige revisión. Una respuesta no demuestra que todas las preguntas estén atendidas solo por contener texto o números.
- Ante «No Overlay», comprueba la ascendencia del contexto que crea menús/selección. No declares éxito desde ErrorWidget. En el SDK que incluye `Overlay.wrap`, úsalo para hijos reconstruibles: `initialEntries` no actualiza sus closures al cambiar el widget. Revisa remove/dispose si administras entradas manualmente.
- Para borradores manuales, la hoja debe ser dueña de un ExecutionBudget que cancela en dispose. Las zonas hijas enlazan y liberan su cancelación con la del padre; HTTP usa requestId y LiteRT/MNN sus canceladores existentes. No descargues el modelo compartido ni canceles solicitudes de otros chats para cerrar una vista previa.
- En turnos personales de estado vivo, algunos motores locales pueden terminar en texto natural aunque el contrato pida JSON; acepta solo incertidumbre explícita o una pregunta recíproca sin afirmaciones, y conserva bloqueadas las afirmaciones sobre planes, ubicación o actividad sin datos.
