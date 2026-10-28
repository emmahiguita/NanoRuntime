# Corrección de respuestas de bienestar — 2026-10-16

## Cambio

La guarda de actividad del dueño ya no interpreta la cláusula de cortesía «estoy bien»/«ando bien» como actividad física. Reconoce el límite de cláusula; conserva la evaluación del resto de la respuesta. «Estoy bien en casa», «estoy bien, estoy trabajando» y «estoy bien pero tengo hambre» siguen retenidas sin evidencia.

El sistema de conversación personal, tanto compacto como completo, pide interpretar errores ortográficos, abreviaturas y signos usando contexto y aclarar ambigüedades. Esto no demuestra comprensión universal ni añade respuestas prefabricadas.

## Verificación

- 8 regresiones nuevas: 3 permiten el bienestar cotidiano a través del motor de decisión; 5 conservan la retención de actividad no verificada. No son inferencias reales del modelo.
- 67 pruebas existentes de agente personal: pasan tras actualizar tres expectativas desfasadas. Los mismos tres fallos se reprodujeron antes de aplicar la corrección: razón antigua del rechazo de eco y dos expectativas de FastPath que contradicen el flujo contextual actual.
- Total: 75 pruebas, todas pasan.
- Análisis estático de los módulos afectados y pruebas: sin incidencias.
- Compilación fullSideload debug arm64: exit 0.
- Instalación sobre el teléfono conectado: Success; datos conservados. lastUpdateTime 15:59:56, nuevo PID 27601.
- Arranque: suscripción a notificaciones activa. El snapshot inicial deduplicó mensajes anteriores; no se forzó su reenvío.

## Prueba real posterior

El usuario envió dos mensajes diferentes. Ambos llegaron a Nano:

- Primer turno (13 caracteres): carga MNN 13496 ms, prefill 38210 ms, redacción 45401 ms. El segundo mensaje llegó durante la generación; el primero terminó ignored por supersede. No se envió una respuesta obsoleta.
- Segundo turno (16 caracteres): prefill completo 35826 ms, TTFT 36903 ms, 21 tokens a 4.00 tok/s, redacción 41356 ms. Borrador de 65 caracteres sin eco. Llegó a dispatch a las 16:07:24.808.
- 16:07:25.518: terminal replyDispatched, resultado replyDispatchedUnverified, REMOTE_INPUT_ACCEPTED. El bloqueo original no se reprodujo en este turno; Android aceptó la respuesta.

## Pendiente de confirmación

Confirmación visible de recepción en WhatsApp y varios turnos de corrección/referencia. No se declara entrega por aceptación de RemoteInput ni 100% de funcionamiento sin esa evidencia.

La corrección no modifica backend, pesos ni cache KV. La latencia MNN medida antes del cambio (aproximadamente 23–27 s por respuesta en los turnos observados) sigue requiriendo medición independiente.
