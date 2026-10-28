# Auditoría de Nano Negocio y WhatsApp Business API

Fecha: 18 de octubre de 2026, America/Bogota.

## Dictamen

**No está completo para operar las dos líneas mediante la API oficial.**
Existe una base real de gateway, webhook firmado, almacenamiento, bandeja,
catálogo y envío de texto. Sin embargo, la ruta oficial está parcialmente
conectada y tiene incompatibilidades pendientes. WhatsApp instalado, WhatsApp
Web y Cloud API son transportes distintos y no deben presentarse como equivalentes.

Alcance: lectura de código móvil y `Nanoai/server`, índice existente y documentación
primaria de Meta. No se modificó código, configuración, números ni credenciales.
No se ejecutaron pruebas, compilaciones, instalaciones, acciones en el teléfono,
registro de números, automatizaciones ni mensajes. Este documento es el único cambio.
No se consultó el estado privado de Meta ni la configuración cifrada del dispositivo.

## Los dos números solicitados

| Número | Evidencia encontrada | Falta |
|---|---|---|
| 3203527283 | Aparece en `benchmark/c14_benchmark.dart:101,109` como contacto de escenarios de prueba. | Acreditar si será línea emisora o destinatario; verificar su registro empresarial y Phone Number ID real. |
| 3225133665 | Sin asociación localizada a una línea de Cloud API en los archivos revisados. | La misma verificación de titularidad, función y registro. |

Si ambos son números colombianos, su formato internacional sería +573203527283 y
+573225133665. **Esos números no son los Phone Number ID asignados por Meta.**
No se puede afirmar que no estén registrados externamente; no se revisó su cuenta.
Tampoco se puede vincularlos pegándolos en el campo del identificador técnico.

Meta exige los activos empresariales, identificador del número, autorización y
registro correspondientes. Fuente: [colección oficial de Meta en Postman](https://www.postman.com/meta/whatsapp-business-platform/documentation/wlk6lh4/whatsapp-cloud-api?entity=request-13382743-eb9a6721-1056-4db2-b00a-2290e04b5b5d).

## Hallazgos que impiden declararlo completo

### 1. Prioridad alta: una sola línea por configuración

`server/whatsapp_templates_api.py:44` obtiene un único
`META_WHATSAPP_PHONE_NUMBER_ID`. `whatsapp_webhook_security.py:22` delimita el
webhook al mismo par WABA/número. El móvil guarda una única conexión global
en `meta_templates_api.dart:39`.

Consecuencia: una instancia no selecciona entre tus dos números emisores. Haría
falta configuración por línea y enrutamiento por cuenta/número, o instancias
separadas con selección explícita. No se implementó ninguna de estas opciones.

### 2. Prioridad alta: bandeja oficial no equivale al flujo completo del agente

`meta_inbox_controller.dart:9` lee y persiste eventos; no redacta ni envía.
`server/whatsapp_webhook_api.py:97` verifica y guarda el webhook, sin ejecutar
el agente. El MCP del gateway es de lectura (`server/whatsapp_mcp.py`).

La salida Cloud existe en `WhatsAppToolHandler.sendMessage`, mediante
`ConfiguredWhatsAppMessageProvider`. En cambio, la respuesta de reglas de
notificaciones sigue exigiendo RemoteInput en `rule_dispatcher.dart:500`.
No se encontró una cadena de entrada oficial → conversación empresarial →
borrador/revisión → respuesta por la misma línea oficial equivalente a esa ruta.
La bandeja oficial revisada tampoco incorpora un editor de respuesta.

Para un flujo manual completo, el pendiente es conectar selección del chat y
línea, borrador opcional, revisión humana y envío oficial. No es necesario activar
respuestas automáticas para corregir esa desconexión.

### 3. Prioridad alta: incompatibilidad con mensajes salientes `echo`

El servidor devuelve eventos `echo` con dirección outbound:
`whatsapp_history_models.py:24` y `whatsapp_history_store.py:51,75`.
El móvil solo admite `message` y `status` en `meta_inbox_models.dart:30`.
Además, `_merge` descarta cualquier tipo distinto de `message`
(`meta_inbox_controller.dart:84`).

Consecuencia deducida del código: una página que contenga un echo puede fallar
al decodificarse. Admitirlo en el parser sin conservar su dirección tampoco bastaría.
No se reprodujo con mensajes reales; debe corregirse el contrato entre ambos lados.

### 4. Prioridad alta: envío oficial limitado a texto

`server/whatsapp_templates_api.py:109` construye siempre `type: text`.
Crear/listar/editar plantillas sí está implementado, pero eso no las envía.
No se localizó transporte saliente oficial para plantillas, PDF, imágenes, audio
o Flows en esa ruta. Compartir desde Biblioteca usa otro mecanismo.

`MetaWhatsAppFlowComposer` construye datos, pero no se localizaron consumidores
de producción de `buildCheckoutFlow` o `applySubmission` en `lib`.
Su existencia no prueba formularios enviados y procesados de extremo a extremo.

### 5. Prioridad media: estados de entrega e historial incompletos

El servidor conserva eventos status. El modelo móvil no conserva `provider_state`
y `_merge` omite estos eventos. Los envíos salientes tampoco se registran en un
outbox desde el endpoint de envío revisado. No hay una vista completa que enlace
texto saliente, WAMID, aceptado, enviado, entregado, leído o fallido.

Es correcto que el proveedor informe accepted con WAMID; eso no demuestra entrega.
La propia pantalla `MetaInboxScreen` advierte que aún no incluye texto saliente.

### 6. Prioridad media: sincronización canónica sin confirmación de escritura

`meta_inbox_controller.dart:90` usa `unawaited(_persistCanonical(event))`, mientras
el cursor avanza en la lectura de cambios (`:157`). No hay confirmación/reintento
local en ese punto si falla el almacén canónico. La evidencia sigue en el servidor,
pero su llegada al contexto local no queda garantizada por avanzar el cursor.

### 7. Pendiente operativo: conexión real no acreditada

`MetaTemplatesApi.connection()` considera ready la presencia de endpoint y clave;
no comprueba Meta. El health del gateway distingue configuración de validación
remota, lo cual es correcto. Esta auditoría no comprobó HTTPS desplegado, token
vigente, registro de cada línea, suscripción WABA ni llegada de eventos reales.

## Lo que sí existe y debe reutilizarse

- Webhook con HMAC, verificación de ámbito, persistencia y deduplicación por WAMID.
- Credenciales Meta en servidor; claves Nano separadas para lectura, envío y administración.
- HTTPS obligatorio en el cliente, redirecciones desactivadas y solicitudes acotadas.
- Bandeja paginada; polling móvil de ocho segundos mientras la ruta está activa,
  con cancelación de timer/cliente al salir. No se afirma servicio permanente.
- Catálogo, precios, disponibilidad, políticas y memoria comercial existentes.
- Biblioteca/Tienda compartidas; una biblioteca accesible no equivale a adjuntos enviados por Cloud API.
- Separación del agente Personal y Negocio y mecanismos de control humano.

## Orden recomendado, sin aplicar cambios

1. Confirmar la función de cada número y obtener su correspondencia real con Meta.
2. Resolver selección y aislamiento de las dos líneas.
3. Corregir echo, dirección, estados y confirmación de persistencia.
4. Completar primero la respuesta manual oficial; después decidir si se desea automatización.
5. Conectar envío de plantillas y multimedia al transporte oficial existente.
6. Validar manualmente recepción y respuesta autorizadas por cada línea, con WAMID
   y estados del proveedor. Sin esa evidencia, no declarar operación completa.

## Diseño de inicio de perfil

Queda pendiente una revisión específica del perfil/cuenta. `AccountCenterScreen`
usa `ProfileSocialCover` y `ProfileFormSections`; es una pantalla distinta del
inicio operativo y del acceso. Los cambios anteriores en esos otros inicios
no acreditan que el perfil solicitado esté terminado. No se cambió su diseño aquí.

## Límite del informe

Los hallazgos son estáticos, no pruebas de explotación ni resultados de ejecución.
El índice puede estar desactualizado; los puntos principales se contrastaron con
los archivos actuales. Las recomendaciones no autorizan ni activan automatización.
