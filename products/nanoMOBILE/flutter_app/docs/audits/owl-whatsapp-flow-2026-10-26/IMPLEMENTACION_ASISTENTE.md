# Implementación del asistente Búho

## Correcciones y responsables

- `nano_turn_receipt.dart`, `nano_ai_controller_submission.dart`: admisión única y
  resultado propio por turno; ocupado no devuelve una respuesta anterior.
- `nano_ai_controller.dart`, `nano_ai_query.dart`, `nano_ai_downloads.dart`,
  `nano_ai_panel_state.dart`: estado y cancelación; el bloqueo dura hasta liberar
  realmente la tarea. El dictado se añade, el prompt externo conserva reemplazo.
- `nano_local_provider.dart`, `nano_providers.dart`, `nano_ai_models.dart`,
  `nano_assistant_prompt.dart`: modelo seleccionado, disponibilidad dinámica,
  cancelación por requestId, conexión propietaria e instrucciones sin historial.
- `nano_assistant_voice.dart`, `nano_floating_wrapper.dart`, `scaffold_shell.dart`:
  una sesión de voz Flutter, liberación al salir/reemplazar/desmontar.
- `nano_action_port_adapter.dart`, `nano_action_intent_resolver.dart`,
  `nano_artifact_commands.dart`: órdenes explícitas y artefactos persistidos;
  una acción desconocida pide aclaración, nunca simula una captura exitosa.
- `nano_prepared_attachment.dart`, `nano_attachment_commands.dart`,
  `nano_assistant_attachments.dart`: selección real y contrato compartido de adjuntos.
- `nano_assistant_composer.dart`, `nano_assistant_panel.dart`,
  `nano_assistant_panel_view.dart`, `nano_assistant_panel_actions.dart`,
  `nano_assistant_panel_components.dart`, `nano_floating_assistant.dart`,
  `nano_floating_assistant_view.dart`: micrófono/lectura/adjunto, borrador conservado,
  acciones conectadas y controles bloqueados durante su operación propietaria.
- `nano_overlay_runtime.dart`, `nano_overlay_files.dart`: mismo controlador para
  Flutter y Android; selección, voz y resultados tipados sin otro motor.
- Android `NanoVoiceCapture.kt`, `NanoPanelVoiceInput.kt`: reconocimiento real,
  generación para ignorar callbacks tardíos, cancelación y liberación del micrófono.
- Android `NanoPanelSpeechControl.kt`, `NanoPanelAttachments.kt`, `NanoPanelTools.kt`:
  lectura bajo demanda y selección de los proveedores reales.
- Android `NanoScreenReader.kt`, `NanoPanelScreenContext.kt`: una sola ventana de
  aplicación externa y límites explícitos de texto accesible, sin fingir visión.
- Android `NanoGeminiInputBar.kt`, `NanoGeminiOverlayView.kt`, `NanoOverlayActions.kt`,
  `NanoOverlaySession.kt`, `NanoFloatingService.kt`: borrador independiente de la
  ventana y resultados publicados al reabrir; generaciones evitan sobrescrituras.
- `AndroidManifest.xml`: visibilidad del servicio de reconocimiento Android.

Rutas Dart bajo `lib/features/chat/nano_everywhere`, salvo `lib/core/router/scaffold_shell.dart`.
Rutas Kotlin bajo `android/app/src/main/kotlin/dev/nanoai/mobile/services`.

## Verificación autorizada

Análisis estático Dart de `nano_everywhere` y `scaffold_shell.dart`: sin incidencias.
Revisión de espacios/diff y tamaño de fuentes afectadas: documentada en `VERIFICACION.json`.
No se crearon ni ejecutaron tests, benchmarks, envíos o recorridos de teléfono.
La compilación y la instalación se registran por separado, con hash del APK.
Los avisos del SDK Android y dependencias no se presentan como pruebas aprobadas.

## Límites

La revisión automática rechazó añadir historial de conversaciones a todos los
proveedores, por posible exposición a destinos web. Se aplicó la alternativa:
solo petición actual y contexto de pantalla expresamente solicitado, sin historial.
El diálogo actual no añade memoria conversacional ni perfiles privados al proveedor.
No se certifica automatización universal, entrega de mensajes, visión completa,
reconocimiento de voz offline, ausencia de errores ni mejoras térmicas sin observarlos.
Ver capacidades y recorrido manual en `CAPACIDADES_WHATSAPP.md`.
