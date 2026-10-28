# WhatsApp sin respuesta visible tras RemoteInput — 2026-10-16

El usuario confirmó que no recibió respuesta. Por ello la aceptación RemoteInput anterior no cuenta como éxito de extremo a extremo.

## Evidencia

- 16:07:25.394: Android inició PID 31425 de com.whatsapp para consumer.notification.DirectReplyService.
- 16:07:25.518: Nano registró REMOTE_INPUT_ACCEPTED, replyDispatchedUnverified.
- 16:07:27.028: killinfo para PID 31425; 16:07:27.089 am_proc_died. Android mató el proceso receptor aproximadamente 1.6 s después de iniciarlo.
- WhatsApp también mostraba reinicios repetidos de MessageService, sin crash Java en el buffer disponible.
- Medición posterior de Nano: TOTAL PSS 4549040 kB, TOTAL RSS 441180 kB, TOTAL SWAP PSS 4183529 kB. No confundir la huella total con RAM residente: gran parte estaba intercambiada.
- MemAvailable 507876 kB, MemFree 126984 kB en teléfono con MemTotal 7823528 kB.

La secuencia y la presión de memoria justifican liberar el modelo ocioso antes del transporte. No demuestran por sí solas el motivo interno exacto de WhatsApp ni la entrega de aquel intento. No se reintenta el despacho incierto.

## Corrección

El composition root inyecta una limpieza posterior al borrador completo (incluidos retries). Antes de devolverlo al transporte, el supervisor MNN comprueba MemAvailable. Si es menor a 1 GiB y no hay solicitudes admitidas, cierra el modelo bajo LocalModelGate, libera su propiedad y registra NanoMnnMemory. No cancela inferencias activas ni fuerza un envío.

El adaptador invalida su selección cargada cuando el nativo libera los pesos. La ruta de ensureReady existente comprueba isReady y recarga en el siguiente turno. El historial durable no se borra. El costo de recarga puede aumentar la latencia; no se declara optimización de velocidad.

## Verificación

- Análisis estático de adaptador, writer y composition root: sin incidencias.
- 75 pruebas de conversación y regresión de bienestar pasan.
- fullSideload debug arm64: compilación correcta e instalación Success.
- playStore debug arm64: compilación correcta.

## Resultado real de la corrección

- Mensaje nuevo admitido a las 16:12:20; carga MNN 14329 ms; prefill de 401 tokens 28066 ms; TTFT 28888 ms; 14 tokens a 4.17 tok/s. Borrador terminado a las 16:13:10.
- 16:13:10.801: NanoMnnMemory confirmó liberación del runtime ocioso con availableKb=491196.
- 16:13:11.094: dispatch; 16:13:12.764: REMOTE_INPUT_ACCEPTED.
- MemAvailable posterior 3890968 kB. Huella Nano posterior: TOTAL PSS 768590 kB, TOTAL RSS 674508 kB, TOTAL SWAP PSS 195874 kB.
- WhatsApp inició DirectReplyService PID 3744 a las 16:13:12.630 y seguía activo en la comprobación posterior.
- El usuario confirmó: «sí, respondió un minuto después». Esto aporta confirmación humana de recepción de este intento, además del despacho Android.

El fallo de falta de recepción queda resuelto en el intento observado. Quedan pendientes latencia, conversación extendida, cambios de modelo, ciclo en segundo plano y otros dispositivos; no se certifica funcionamiento universal.
