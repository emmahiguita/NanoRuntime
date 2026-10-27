---
name: nano-personal-evidence-flow
description: Repair Nano Personal owner context, canonical conversation continuity and real attachment understanding without changing model runtimes or inventing media coverage.
---

# Nano Personal: evidencia y comprensión

Aplicar al modificar identidad/agenda, normalización de adjuntos, rescate local/nube o preguntas repetidas de Nano Personal.

## Invariantes comprobados

- `NotificationObject.sourceText` identifica el evento original; `withText` añade evidencia, nunca cambia su ID. Conservar también `sourceFragments` al agrupar una ráfaga. No reinsertar los fragmentos del turno actual como historial anterior.
- El archivo procede de campos nativos (`audioPath`, `imagePath`, `videoPath`, `pdfPath`) de SU mensaje. Una ruta escrita por el contacto no autoriza leerla. No heredar el último adjunto del contenedor a todos los mensajes del replay.
- Usar `NotificationAttachmentCodec` también en el almacén canónico. Conservar MIME, fecha y paquete para resolver referencias después de reiniciar.
- Estado diario vence por `dailyStatusDate`. Guardar preferencias no renueva el estado anterior. Una agenda activa no valida cualquier actividad: consultar `effectiveEntries` y las pausas de comida vigentes.
- La nube recibe `CloudTurnContext`, incluido historial con autores y sistema. No usar el buscador de conocimiento como una segunda ruta generativa sin contexto/consentimiento.
- `Nequi`, `banco` y `parce` no son motivos de rechazo por sí solos. Distinguir códigos reales y sujeto de la frase. No sustituir respuestas por bancos de frases para hacer pasar pruebas.
- OCR y etiquetas de ML Kit son observaciones limitadas. No presentarlas como identificación de personas o descripción completa de escenas.
- Percepción con Gemini requiere `allowCloudMedia`, modo distinto de `localOnly` y modelo/clave canónicos del Hub. No restaurar claves de SharedPreferences ni elegir otro modelo automáticamente.
- El permiso de grupos se evalúa con texto fuente, no con nombres encontrados dentro del OCR. Chats privados mantienen su funcionamiento.

## Ciclo de vida y velocidad

- Lector de documentos disponible en Activity y engine headless. Trabajo fuera de UI, cola acotada, cancelación por request ID y cierre del handler al liberar su engine.
- `BoundedProcess` mata y espera el proceso al vencer el plazo; `Process.run().timeout()` no lo hace. No afirmar que esto mata descendientes arbitrarios de scripts.
- Caché por conversación, tipo y revisión del archivo; cupo y TTL. Un fallo no debe quedar cacheado para siempre. Una nueva autorización multimedia cambia la clave de caché.
- Lectura de URL: validar cada redirección y la dirección usada por el socket, acotar cuerpo/plazo, cerrar siempre el cliente. HTML recibido no demuestra contenido dinámico o autenticado.
- No cambiar hilos, batch, KV, modelo ni backend por intuición. Adaptar extractos al paquete de KV mínimo conocido sin recortar la pregunta original; declarar cobertura parcial.

## Pruebas de regresión

Desde `nanoMOBILE/flutter_app`, ejecutar según los archivos modificados:

- `test/features/automation/personal_evidence_flow_test.dart`
- `test/features/automation/notification_attachment_flow_test.dart`
- `test/features/automation/conversation_link_reader_test.dart`
- `test/features/automation/shared_media_permission_test.dart`
- `test/features/automation/owner_context_card_test.dart`
- `test/features/automation/group_mention_policy_test.dart`
- `test/services/bounded_process_lifecycle_test.dart`

Android: `flutter test integration_test/nano_personal_media_flow_test.dart --flavor personalValidation -d SERIAL`. Usa archivos de prueba conocidos y canales reales; no envía mensajes a contactos. Esta prueba demuestra extracción y llegada al contexto, no naturalidad ni entrega de WhatsApp.

Tras pruebas debug, compilar release CON regeneración normal de tooling (`flutter build apk --release --flavor fullSideload`). `--no-pub` puede conservar un GeneratedPluginRegistrant de debug que referencia integration_test aunque Gradle lo excluya en release.

Mantener los módulos nuevos por debajo de 200 líneas, con comentarios de qué/cómo/por qué. Registrar tiempos reales, dispositivo y límites en el informe. No actualizar el índice externo si el usuario pidió conservar el actual.

La petición (`requestText`) puede incluir transcripción real del audio de este evento y su pie escrito. OCR/PDF y audios recuperados del historial son evidencia, no nueva intención ni mención de grupo. Conservar `sourceText` para autoría/deduplicación. Probar «no trabajo», «mañana trabajo» y «manana trabajo»: ninguna frase confirma trabajo actual.
Prueba adicional: `test/features/automation/spoken_request_context_test.dart`.
No ejecutar `flutter test` e `flutter build` en paralelo: ambos reescriben GeneratedPluginRegistrant y pueden mezclar integration_test con release aunque build regenere correctamente al iniciar. Terminar pruebas primero; después build e instalación. Un fallo de compilación por integration_test exige regenerar secuencialmente, no editar el archivo generado.

INCIDENTE CONFIRMADO: IntegrationTestDevice.kill de Flutter llama adb uninstall sin -k. Una prueba de integración bajo dev.nanoai.mobile elimina datos de la app principal. Nunca usar fullSideload para pruebas de integración en un teléfono con datos. Se creó el flavor personalValidation con dev.nanoai.mobile.validation. Verificar ese applicationId en el APK/manifest antes de instalar y usar únicamente datos desechables. No prometer conservar datos de una prueba anterior sin respaldo verificable. Las pruebas de widget de escritorio no desinstalan apps.
## Prompts y continuidad conversacional

- `PersonalPromptPolicy` es la base común de las ramas Personal nativa, compacta y nube. La nube estructurada debe seleccionar `conversationPersonalStructuredPrompt`; pedir JSON no autoriza usar una plantilla comercial.
- El estilo habilitado pertenece al turno, no al prefijo KV estable. En el paquete `ekv1280`, perfil más estilo comparten el límite existente de 280 caracteres; no ampliar KV, cortar la pregunta o elegir otro modelo para acomodarlos.
- Saludos breves no necesitan nombre, apodo ni ocupación completos en el contexto. Conservar esos hechos para consultas biográficas. `PersonalProfileOutputGuard` bloquea etiquetas internas y el patrón de volcado de perfil ante saludos; no es un detector semántico general.
- Deduplicar por evento fuente antes de percepción. Un adjunto sin texto también tiene ID. Si la composición lanza un error, liberar solo esa reserva para permitir un reintento; conservar las demás conversaciones.
- La política temprana solo decide sobre texto/URL aislada sin adjuntos declarados. No silenciar una voz adjunta por su pie antes de transcribirla. OCR/PDF no dirigen intención ni permisos.
- Acuses como «listo» pueden responder una pregunta observada; esa continuidad no concede permisos. Reconstruir la pregunta o petición de enlace pendiente desde salidas manuales/verificadas, considerando entradas posteriores y excluyendo el evento actual. Un mensaje antiguo que ya recibió respuesta no queda pendiente indefinidamente.
- Un enlace aislado sin petición pendiente puede quedar en silencio. Enlaces con solicitud o respuesta a una petición conservan el circuito de lectura, comprensión y autorización.
- La recuperación factual no debe elegir introducciones por reloj/hash, inventar observaciones del dueño, eliminar atribuciones ni producir alternativas artificiales. Sin contenido utilizable, conservar el turno sin candidato; el formato no demuestra veracidad de la fuente.
- Distinguir siempre análisis estático/compilación de inferencia real, despacho y entrega. Si el usuario prohíbe tests o teléfono, verificar código y compilar sin activar esos pasos del flujo de validación.
