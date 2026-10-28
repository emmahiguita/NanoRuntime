# Separación Personal/Business y conversación local — 16-10-2026

## Alcance real

El usuario confirmó que utiliza únicamente WhatsApp instalado en el teléfono. La validación operativa corresponde a NotificationListener + respuesta directa Android. No hay una conexión MCP/gateway personal confirmada ni una captura Cloud API en vivo validada en este trabajo. La arquitectura adjunta es una referencia; no se declara desplegado su gateway por existir clases o tablas locales.

## Correcciones

- Personal y Negocios conservan sus agentes y ámbitos existentes. Las claves remotas nuevas separan fuente, cuenta y conversación; el resolvedor de direcciones reconoce MCP personal y Meta Business explícitamente.
- Los IDs canónicos nuevos incluyen proveedor y conversación. SQLite limita el ID externo a proveedor/conversación; la huella de contenido solo deduplica eventos sin ID real. Dos mensajes distintos con texto/fecha idénticos conservan ambos IDs.
- Se eliminó la promoción destructiva por parecido de texto en 30 segundos. Una notificación y un mensaje MCP/Cloud conservan sus fuentes. Solo se actualiza el mismo ID real dentro de su proveedor y conversación.
- La migración del índice copia todas las columnas e IDs, comprueba cantidad de filas y cambia la tabla dentro de la misma transacción. Se recrean los índices. Una falla revierte la operación.
- El lote MCP valida fuente, cuenta, fecha e identidad. Un rechazo real revierte mensajes y cursor; un replay identificado es idempotente. El cursor no retrocede y la exclusión de solicitudes es por cuenta, no global. El adaptador no inventa una fecha para un evento que no la trae.
- Las respuestas a contactos no consultan por defecto la agenda privada ni los fragmentos de otras conversaciones. Ese acceso requiere un consumidor privado del dueño que lo habilite expresamente.
- Se retiraron los bancos de frases de respaldo de agenda/fecha. Una agenda vacía no se convierte en «día libre». El reloj puede ser evidencia, pero la respuesta debe provenir del motor o de una fuente configurada aplicable.
- El marco heurístico ya no se inyecta como una orden de confirmar tareas o prometer encargos.
- KV se reutiliza únicamente con sesión, sistema y turnos materiales iguales. Un sufijo recortado, una alternativa elegida o un cambio de contexto obliga a reconstruir la conversación sin descargar sus pesos.
- La respuesta automática solicita un único mensaje. Las opciones no se confunden con varias intervenciones ya enviadas. Se mantiene el historial de despachos con el marcador «entrega no verificada» y se excluyen efectos desconocidos.
- El sistema personal distingue explícitamente al contacto (`user`) del asistente. Se agregó rechazo y una regeneración acotada para el fallo observado de presentarse con el nombre del contacto. Las guardas de actividad inventada permanecen activas.
- La procedencia de notificaciones queda marcada como `preview`, `complete=false`; los mensajes normalizados de MCP/Meta conservan cuenta, chat y `source_observed`. Ninguno de esos metadatos certifica historial completo.

## Verificación de software

- 105 pruebas Dart focalizadas: aprobadas en la ejecución final.
- 6 pruebas Kotlin de identidad del historial y descarte de KV: aprobadas.
- SQLite real en el teléfono, base sintética en memoria: aprobó conservación del esquema anterior e IDs, aislamiento de cuentas/fuentes, repeticiones legítimas, rollback de lote y cursor, e idempotencia.
- Análisis focalizado de archivos modificados: sin incidencias en las ejecuciones indicadas. No se afirma que todo el repositorio esté libre de avisos.
- Compilación debug para validación e instalación conservando datos: realizadas. Compilación release para el teléfono: realizada; la última reconstrucción incorpora la resolución de cuentas remotas. Firma de desarrollo, sin publicación externa.

## Conversación con pesos reales

Prueba sintética en OPPO CPH2557: presentación con errores al escribir, corrección Lucas → Sara, referencia al nombre/instrumento y una pregunta sobre día y noche. No se leyeron chats privados ni se enviaron mensajes sintéticos a WhatsApp.

| Paquete | Backend medido | Resultado observado |
|---|---|---|
| Qwen3 0.6B no-think | CPU | Falla pertinencia/autoría y conocimiento, incluso con temperatura 0.8 y reconstrucción en cada turno. No se atribuye todo el fallo a KV. |
| LFM2.5 230M | CPU | Rápido, pero repite Lucas tras corregir a Sara y falla la explicación general. |
| Gemma-4-E2B-it | GPU real | Conserva la corrección y guitarra, y distingue al contacto. La explicación general sobre día/noche fue incorrecta. Aceptación conversacional parcial; no precisión factual universal. |

Gemma: SHA-256 del archivo instalado `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c`, coincide con el catálogo. Inicialización GPU: 6719 ms. TTFT sintético: 5517, 1258, 1307, 1412 ms. Duración total por turno: 8337, 3622, 2731, 6452 ms. PSS al cargar aproximadamente 1,69 GiB. Estas cifras no son una medición de latencia completa de WhatsApp con perfil/historial real.

La prueba inicial buscaba «Tierra» y emitió PASS de forma demasiado débil. La revisión del texto detectó que confundía órbita con rotación; no se cuenta como aprobación factual. El fixture se fortaleció para exigir rotación/eje y detectar apropiación de nombres en cualquier turno.

Se conserva Gemma LiteRT, que ya estaba seleccionado por el usuario, y el modo de automatización `sameAsChat`. No se modificaron permisos de envío ni contactos autorizados.

## Pendiente de aceptación real

La compilación, los tests y un despacho aceptado no prueban llegada por WhatsApp. Falta contrastar una conversación nueva en el otro teléfono, con una corrección y una referencia posterior, y medir su recorrido real. La precisión del conocimiento general continúa dependiendo del modelo y de evidencia externa disponible; no se promete respuesta correcta a cualquier pregunta.

Versión release final instalada con adb install -r (Success) y MainActivity abierta. El registro confirma suscripción activa del canal de notificaciones. Pendiente el intento nuevo del contacto para verificar generación, despacho y recepción.

## Regresión detectada en WhatsApp real
El nuevo intento fue admitido, Gemma GPU cargó en 8464 ms y generó 63 caracteres en 13880 ms. El parser descartó texto natural de actividad sin coincidir con su lista de incertidumbre; hubo reintento y resultado no_candidate, sin despacho. Se eliminó esa lista como condición de admisión de texto: la decisión factual posterior sigue reteniendo actividad física inventada. Once pruebas de regresión pasan, incluida conversación natural y retención de actividad sin evidencia. Análisis focalizado sin incidencias. Nueva compilación e instalación pendientes.

Corrección posterior: release recompilada en 112,5 s, instalada conservando datos (Success) y abierta. 90 pruebas focalizadas pasan y análisis sin incidencias. Pendiente recepción real tras esta segunda instalación. No se considera reparado el recorrido hasta observarlo.

## Segundo intento real: actividad retenida y corrección acotada
El saludo generó 42 caracteres en 12557 ms y fue supersedido por un mensaje nuevo. El segundo turno produjo 55 caracteres en 9811 ms, pasó el parser y quedó holdForApproval (confianza 0,30) por actividad presente sin evidencia. El problema ya no era ausencia de inferencia. Temperatura Android: estado térmico 0; no se atribuye el fallo al calor.

Se distinguió presencia conversacional de actividad física en affirmsOwnerActivity, retirando solo las cláusulas de conversación con el contacto y las preguntas con signos españoles. Las afirmaciones físicas añadidas siguen retenidas. Se compactaron las instrucciones personales y el aviso de cobertura (sin recortar mensajes), se pidió evitar preguntas encadenadas y se permitió una única regeneración real por actividad no verificada dentro del presupuesto existente. Se conservaron los cambios cloud concurrentes del otro trabajo.

Validación: 25 pruebas de actividad/bienestar pasan y análisis focalizado sin incidencias. Una ejecución de la suite legacy adicional falló en una expectativa sobre una frase aleatoria de almuerzo de PragmaticFastPath (respuesta observada: todo tranquilo...); no se cuenta como suite verde ni se modificó ese banco ajeno al cambio.

Gemma GPU real, prueba sintética con sistema compacto final, temperatura 0,3 y máximo 64 tokens: saludo TTFT 4756 ms / total 5593 ms; actividad con typo TTFT 1281 ms / total 3222 ms; continuación TTFT 1238 ms / total 5010 ms. Segundo y tercer turno reutilizaron conversación. PSS 1775350 KiB. La salida sintética de actividad se añadió a la prueba del parser y decisión y permite autoSend. No prueba recepción por WhatsApp ni latencia en el historial real.

Se está construyendo release final. No se afirma recepción real ni recuperación completa hasta observar un intento posterior a la instalación.
