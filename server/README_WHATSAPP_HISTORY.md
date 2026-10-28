# Bandeja oficial: lectura y sincronización

Implementación del 13 de octubre de 2026.
Reutiliza el gateway, su autenticación y la SQLite del webhook. No crea mensajes de ejemplo.
No altera WhatsApp Web, notificaciones, agente personal ni credenciales de Meta.

## Rutas nuevas

Todas requieren la llave existente en la cabecera `X-Nano-API-Key`.
No coloques la llave en URL, chat, capturas, logs ni código versionado.
El token de Meta continúa solamente en el servidor.

| Método y ruta | Resultado |
| --- | --- |
| GET /api/v1/whatsapp/conversations | Último mensaje recibido por interlocutor |
| GET /api/v1/whatsapp/conversations/{peer_id}/messages | Mensajes recibidos del chat exacto |
| GET /api/v1/whatsapp/changes | Eventos recibidos desde una secuencia, incluidos estados |

Parámetros:

- `limit`: entre 1 y 100; lista/historial por defecto 50, cambios 100.
- `before`: secuencia exclusiva, para cargar páginas anteriores.
- `through`: instantánea devuelta por la primera página; conservarla al paginar.
- `after`: secuencia exclusiva del último cambio confirmado por el cliente.

Las respuestas de lista/historial incluyen `data`, `snapshot`, `scope` y
`next_before`. Los cambios incluyen `next_after` y `cursor`.
Si `next_after` existe, continúa desde `cursor` manteniendo `through=snapshot`.
Cuando no existe, la ráfaga termina y el siguiente sondeo puede omitir `through`.
No avances el cursor antes de aplicar la página.

El cliente no puede elegir otra WABA/número: el ámbito viene de la configuración
del servidor. Una instancia atiende un ámbito, no implementa multi-tenancy SaaS.
Cursores mayores que una bandeja restaurada devuelven 409: recargar, no inventar continuidad.
La caché HTTP de respuestas se desactiva con `Cache-Control: private, no-store`.

## Qué significa el historial

Es evidencia recibida y persistida por el webhook firmado:

- Identidad por WAMID y teléfono real, no coincidencias aproximadas del nombre.
- Orden por secuencia de recepción; la fecha visible conserva el timestamp de Meta.
- Sin timestamp se reconoce fecha desconocida, no se sustituye por hoy.
- Estados de entrega no crean conversaciones ni texto saliente.
- Medios sin texto se identifican por tipo; no se inventa una transcripción.
- No incluye el historial previo a la activación ni los envíos cuyo texto aún no
  se guarda en una cola saliente de Nano.
- El cuerpo completo del webhook no se expone por esta API.

El consumidor actual es de lectura; no responde ni despacha acciones del LLM.
Los eventos de estado permanecen disponibles en cambios, pero su proyección en
mensajes salientes depende de implementar la persistencia de esos envíos.

## Conexión móvil

En Nano: Mensajes → Bandeja oficial de WhatsApp → Conexión segura.
Reutiliza la URL HTTPS y la llave Nano guardadas por el módulo de plantillas.
No requiere copiar el token Meta al teléfono ni permisos de notificaciones.
No cambia automáticamente el proveedor de envío.

La lista abre el historial por teléfono exacto. Cargar anteriores recorre toda
la evidencia recibida disponible. Cambios nuevos se consultan de forma serial
cada 8 segundos después de completar la operación anterior; no es streaming push.
Cada vuelta lee como máximo tres páginas de cambios y conserva el cursor pendiente.
WAMID deduplica mensajes. La lista de conversaciones conserva el evento más reciente
por interlocutor aunque lleguen páginas antiguas.

Las consultas se pausan con la app en segundo plano. Una ruta cubierta no consulta
red. Salir cancela el timer y cierra su HTTPClient. Esto no modifica el servicio
nativo del agente personal ni otros transportes.

El servidor local sigue escuchando solo 127.0.0.1:8010.
El móvil exige HTTPS real: no usar localhost del teléfono ni ignorar certificados.
Antes de conexión móvil hace falta despliegue HTTPS autorizado, callback de Meta
y recepción validada con el número de prueba.

## Diseño y mantenimiento

- `whatsapp_gateway_auth.py`: autenticación común, independiente del token Meta.
- `whatsapp_history_models.py`: contrato del lector y DTO público.
- `whatsapp_history_store.py`: SQL parametrizado, modo read-only e instantáneas.
- `whatsapp_history_api.py`: HTTP, ámbito y errores; SQL fuera del event loop.
- `whatsapp_webhook_api.py`: inyección del lector durante el lifespan existente.
- Índice parcial por cuenta/número/interlocutor/secuencia; migración aditiva,
  sin borrar ni transformar eventos anteriores.
- Bloqueo SQLite máximo 3 segundos y presupuesto de consulta de 2 segundos.
  Una consulta que supera su presupuesto falla; no garantiza latencia ni escala ilimitada.
- En Flutter, `MetaTemplatesApi` conserva conexión/configuración y delega el
  transporte HTTP común a `meta_gateway_transport.dart`; no duplica llaves.
- HTTP no sigue redirecciones con la llave privada. AbortableRequest del paquete
  http 1.6 instalado cancela la solicitud/cuerpo al vencer 25 segundos o destruir
  el cliente; el timeout ya no solo abandona la espera mientras sigue el socket.
- `meta_inbox_controller.dart` gestiona cursor, deduplicación y ciclo de vida.
- Las vistas usan el tema Material de Nano, ancho limitado y contenido desplazable.

## Validación de esta implementación

Se comprobaron registro OpenAPI, sintaxis Python, Ruff y análisis Dart sin errores.
El gateway real local arrancó con su configuración existente. Sin llave, las tres
rutas rechazaron acceso con HTTP 401. El diagnóstico no expuso credenciales.

La SQLite real tiene integridad correcta, índice de historial presente y cero
recepciones/eventos. El estado local informa salida configurada, webhook no
configurado y acceso remoto/HTTPS no validados.

La extracción de la llave cifrada para una consulta autenticada fue bloqueada
por protección de secretos. No se insistió ni se buscó una vía indirecta.
La comprobación autenticada debe hacerse desde un cliente configurado localmente.
No se crearon ni ejecutaron suites de tests ni se insertaron mensajes simulados.

No se validó paginación con mensajes reales: no existen eventos en esta bandeja.
No se enviaron mensajes ni se activó un webhook, túnel, firewall o cuenta externa.
La APK fullSideload debug arm64 compiló correctamente con --no-pub.
Ruta: products/nanoMOBILE/flutter_app/build/app/outputs/flutter-apk/app-fullsideload-debug.apk.
No se instaló en el teléfono en este sprint. Compilación e instalación deben
distinguirse de acceso operativo: una APK compilada no valida conexión a Meta.

## Siguiente paso

1. Completar configuración del webhook en el formulario privado del servidor.
2. Definir y autorizar su despliegue HTTPS y autenticación de clientes.
3. Validar recepción con el número de prueba y confirmar que la bandeja móvil
   muestre esos mismos WAMID, historial anterior y cambios sin duplicados.
4. Integrar el cliente seguro de escritorio y la persistencia/cola de envíos.
5. Después conectar ejecución del agente a los mensajes oficiales.
