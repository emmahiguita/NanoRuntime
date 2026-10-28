# Informe: aparente falta de respuesta de Nano Personal

## Estado comprobado

- Teléfono conectado: VGL7MVFMDYQG8T55 (CPH2557).
- Paquete: dev.nanoai.mobile, PID observado 24307.
- Última actualización instalada: 2026-10-16 11:49:32.
- Modelo seleccionado: Qwen2.5-Omni-3B (MNN).
- Acceso a notificaciones habilitado; NotificationAutomationService activo.
- Agente observado: personal, autonomous, humanOwns=false.
- No se cambió modelo, configuración, permisos ni se enviaron mensajes de prueba.

## Evidencia del turno capturado

Registros del 16 de octubre de 2026, hora local del teléfono UTC-05:

| Hora | Evidencia |
|---|---|
| 11:51:32.283 | MNN prefill completado en 44801 ms |
| 11:51:34.262 | MNN primer token, TTFT 46780 ms |
| 11:51:41.254 | Stop token 151645; 21 tokens generados, 2.36 tok/s |
| 11:51:41.266 | Reintento de calidad completado; genMs=84965 |
| 11:51:41.269 | Borrador válido: inputChars=4, replyChars=67 |
| 11:51:41.331 | Etapa dispatch alcanzada |
| 11:51:41.670 | REMOTE_INPUT_ACCEPTED; replyDispatchedUnverified |

El TTFT y el prefill anteriores pertenecen a la generación nativa que terminó
en ese instante. Los 84965 ms corresponden a la fase de redacción completa,
que incluye el reintento. No son tiempos de cada mensaje ni promedios generales.

## Diagnóstico

1. La entrada llegó al flujo, produjo un borrador y alcanzó el despacho.
2. El cuello de botella observado es el procesamiento MNN del contexto: unos
   45 segundos de prefill en esa generación y unos 85 segundos de redacción total.
3. La implementación JNI configura CPU/4 hilos y ejecuta model->reset() antes
   de procesar cada prompt completo. No conserva el KV conversacional entre turnos.
4. El reintento real de calidad vuelve a pagar ese procesamiento de contexto.
   El fragmento conservado no muestra la causa exacta que rechazó el primer intento.
5. La corrección anterior del presupuesto Qwen3 LiteRT no se aplica a MNN.
   No se observó CONTEXT_CAPACITY_EXCEEDED en el fragmento capturado.
6. Android aceptó RemoteInput: NO demuestra entrega, lectura ni recepción final
   en WhatsApp. No se ha confirmado el resultado final del proveedor.

## Riesgo adicional del código, no fallo probado de este turno

La cola serial de borradores descarta esperas superiores a 45 segundos. Un
turno MNN que dure 85 segundos puede hacer expirar otros turnos en espera;
no se atribuye esa expiración a un chat concreto sin su registro correspondiente.

## Prioridad de corrección

- Reducir el contexto efectivo y el prefill MNN con evidencia del paquete.
- Revisar reutilización segura del estado y reinicios; nunca compartir KV entre chats.
- Acotar el costo de regeneración sin permitir texto rechazado ni respuestas fijas.
- Hacer visible al usuario si está cargando, procesando contexto, regenerando o
  despachado sin confirmación, en lugar de aparentar silencio.
- Verificar el resultado final en WhatsApp sin reintentar despachos inciertos.

## Límites

Lectura de Logcat y revisión del código, sin cambios funcionales ni tests.
El buffer disponible no conserva necesariamente toda la sesión. Este informe
diagnostica el turno capturado, no certifica todos los chats ni posteriores envíos.
