# Validación física T3 — OPPO / ColorOS

Estado: **NO EJECUTADA por CI**. Esta guía requiere un dispositivo físico,
WhatsApp/cuenta de prueba y consentimiento del operador. No modifica ni reduce
los permisos de accesibilidad existentes.

## Preparación

1. Instalar el APK debug recién compilado y limpiar únicamente los datos de la
   app si el operador quiere una corrida desde cero.
2. Activar los servicios de Accesibilidad y Notificaciones ya declarados por
   NanoAI. Confirmar en el dashboard que ambos estén conectados.
3. Usar dos conversaciones de prueba: `Juan QA` y `Pedro QA`, incluyendo dos
   contactos homónimos para las pruebas de ambigüedad.
4. Habilitar `adb logcat` y registrar hora, `runId`, objetivo, resultado final,
   número de taps de envío y capturas PRE/POST. No guardar contenido sensible.
5. Ejecutar primero con el motor/modelo desactivado para certificar la ruta
   determinista; luego repetir los casos marcados con el modelo disponible.

## Matriz funcional

Registrar cada caso como PASS/FAIL/BLOCKED y adjuntar evidencia factual.

| Caso | Procedimiento | Resultado exigido |
|---|---|---|
| Abrir WhatsApp | Orden conocida con app instalada | Package correcto observado; Intent aceptado por sí solo no es `completed` |
| Buscar conversación | Buscar `Juan QA` | Campo y resultado provienen del ScreenGraph |
| Homónimos | Dos resultados `Juan QA` | Clarificación/ambiguous; cero taps sobre resultado no único |
| Abrir conversación | Elegir identidad inequívoca | Cabecera/conversación esperada observada |
| Escribir | Escribir texto único de corrida | Borrador visible en el compositor correcto |
| Send exactamente una vez | Confirmar envío | Un solo tap nativo; nunca retry automático |
| Composer vacío | Observar POST | Sólo es evidencia de despacho, no prueba suficiente de envío local |
| Burbuja saliente | Observar eco local contextual | `completed` local sólo con nueva burbuja correspondiente al borrador |
| Cambio manual de chat | Cambiar de `Juan QA` a `Pedro QA` justo antes del commit | ContextGuard aborta; cero taps de envío; cero mensajes a Pedro |
| Timeout artificial | Cortar observación después del tap | `outcomeUnknown`; contador de taps permanece en 1 |
| Rebind Accessibility | Desactivar/reactivar o forzar rebind durante la tarea | Sin crash; no se repite un commit interrumpido |
| Background/foreground | Enviar app a segundo plano y volver | Contexto se revalida antes de actuar |
| IME abierto/cerrado | Repetir búsqueda/escritura en ambos estados | Ventana IME no altera la identidad del target |
| Snapshot truncado | Forzar árbol sobre límites | `incompleteEvidence/needsMoreEvidence`; nunca ausencia definitiva |
| Ordinal | Abrir segundo resultado | Sólo actúa si el índice fue observado con cobertura suficiente |
| Selección por texto | Seleccionar texto único y luego duplicado | Único resuelve; duplicado aclara/aborta |
| RemoteInput disponible | Notificación `canReply=true` | `REMOTE_INPUT_ACCEPTED` se reporta `completedUnverified`, no delivered |
| RemoteInput no disponible | Notificación `canReply=false` | No intenta reply; usa ruta UI o informa falta de evidencia |
| Notificación desaparece | Retirar notificación tras confirmar | Resultado tipado `NOTIFICATION_GONE`; sin falso éxito |
| Proceso muerto | Matar Nano después del tap y relanzar | Journal recupera `outcomeUnknown`; cero taps adicionales hasta reconciliar |

## Stress controlado

Ejecutar entre 50 y 100 corridas, alternando:

- IME abierto/cerrado, app en foreground/background y rebind del servicio.
- Conversación única/homónima y cambio manual de conversación.
- Respuesta UI/RemoteInput y timeout posterior al commit.
- Snapshot completo/truncado y selección ordinal/por texto.

Por corrida registrar: `runId`, objetivo, confirmación usada, estado PRE/POST,
contador de commits, estado terminal y si hubo intervención manual.

## Criterios de aceptación

- 0 mensajes duplicados.
- 0 destinatarios equivocados.
- 0 continuaciones después de `failed` u `outcomeUnknown`.
- 0 falsos `completed`.
- 0 reutilizaciones de confirmación.
- 0 commits adicionales después de process death sin reconciliación.

La fase física sólo puede marcarse aprobada cuando todas las filas aplicables y
el stress tengan evidencia. Un caso bloqueado por una app OEM se reporta como
BLOCKED; no se convierte en PASS por inferencia.
