# WhatsApp oficial: permisos separados y configuración segura

Implementación del 13 de octubre de 2026. Reutiliza el gateway, SQLite y conexión
HTTPS existentes. No activa envíos automáticos ni cambia WhatsApp Web/notificaciones.

## Permisos reales

| Llave del panel | Lectura REST/MCP | Envío de texto | Crear/editar/borrar plantillas |
| --- | --- | --- | --- |
| Lectura / MCP | Sí | No | No |
| Envío de mensajes | Sí | Sí | No |
| Administrar plantillas | Sí | No | Sí |

El token de verificación del webhook NO es una llave de acceso Nano. App Secret y
token de Meta permanecen únicamente en el PC. La selección del permiso la hace
la ruta, nunca un parámetro del cliente/modelo. Llaves coincidentes se rechazan.

GatewayBoundary verifica permisos antes de leer JSON. Las operaciones Graph
también exigen su permiso: defensa adicional al llamar el servicio directamente.
MCP conserva únicamente sus cuatro herramientas de lectura; no expone envío.

## Migración automática sin pérdida de datos

Abrir el panel o iniciar el servidor carga su configuración privada normalmente.
Si faltan permisos, genera dos llaves aleatorias nuevas y guarda el archivo con
DPAPI, ACL privada, escritura temporal, fsync y reemplazo atómico existentes.
No se imprime, copia ni entrega ninguna llave mediante herramientas del agente.

- La llave anterior se conserva, pero queda limitada a lectura.
- Se conservan token Meta, WABA, Phone Number ID, versión Graph y App Secret.
- Se conserva el token de verificación del webhook y toda la SQLite.
- Antes de la primera migración se guarda una copia todavía CIFRADA en
  settings.before-permissions.dpapi dentro del mismo directorio privado.
- Repetir el arranque no rota las llaves ni sobrescribe esa copia.
- Un archivo ilegible falla sin reemplazarlo. No se crea un token Meta ficticio.

La copia permite recuperación de datos de configuración por el propietario;
volver al código anterior restauraría permisos excesivos y no es un rollback
de seguridad recomendado. No restaurarla ni compartirla sin revisar ese riesgo.

## Cliente móvil

La conexión conserva su URL HTTPS y lectura anteriores. Cada solicitud elige
la llave adecuada por operación. No usa lectura como fallback de escritura.
Los permisos faltantes muestran un error de configuración antes de enviar HTTP.

La configuración nueva se guarda como una única instantánea en Flutter Secure
Storage para evitar mezclar URL de una empresa con claves de otra. Cambiar de
servidor no reutiliza claves anteriores automáticamente. Se conservan valores v1
de lectura para compatibilidad; no se convierten en permisos de envío/admin.

El diálogo ahora contiene entradas ocultas separadas:

1. Lectura / MCP: requerida para consultar la bandeja.
2. Envío: opcional; requerida al elegir explícitamente Meta Cloud para enviar.
3. Administrar plantillas: opcional; necesaria para modificar recursos de Meta.

En el mismo servidor, un campo vacío conserva el valor guardado; desconectar
elimina todos los permisos móviles. Las entradas no muestran claves guardadas,
no permiten autocorrección/sugerencias y sus controladores se liberan al cerrar.
La transferencia de llaves la realiza manualmente el propietario, no el agente.

Una APK anterior sigue leyendo, pero ya no puede escribir con la llave antigua.
No se hace fallback silencioso a WhatsApp Web o notificaciones si Cloud falla.

## Diagnóstico sin simulaciones

Se retiró el comprobador anterior que construía un wamid.test.*, lo firmaba y
publicaba una entrega ficticia en la bandeja. El botón ahora consulta solo health:
no accede a secretos, no usa verify_token en URLs y no realiza POST de eventos.
Su resultado no pretende verificar suscripción, HMAC de un evento real ni entrega.

Comprobar MCP hace handshake HTTP real, tools/list y verifica en el autorizador
que la llave real de lectura no tiene envío/admin. No lee chats ni ejecuta envíos.
El propietario confirmó cuatro lecturas y ausencia de permisos de escritura.

## Evidencia de esta actualización

- Ruff e importación Python correctos; análisis Dart sin incidencias.
- Todos los archivos de código modificados tienen menos de 200 líneas.
- APK fullSideload arm64 debug compilada; no se ejecutaron suites de tests.
- Panel actualizado PID 17768 posee el gateway y responde.
- Local y HTTPS: estado 200, outgoing_configured=true, webhook_configured=false.
- Metadatos confirman archivo cifrado nuevo y copia cifrada anterior; valores no leídos.
- SQLite: integridad ok, cero eventos, cero wamid.test.*; no fue necesario borrar datos.
- Instalación pendiente: Windows detecta OPPO A79 5G y ADB Interface, pero adb no
  lista dispositivos. Android CLI rechazó instalar porque no encuentra el serial
  autorizado. No se desinstaló Nano ni se borraron datos o concedieron permisos.
- Compilar no demuestra instalación ni acceso operativo desde el teléfono.

## App Secret: intervención necesaria del propietario

En Meta Developers, abrir la app Nano y buscar Configuración de la app → Básica
→ Clave secreta de la app. Si Meta exige contraseña/confirmación, completarla
personalmente. El asistente no revela ni copia ese secreto.

En el panel privado: Detener → ingresar App Secret → Guardar cifrado → Iniciar.
Después verificar callback, campo messages y suscripción efectiva en Meta con
la URL actual y el token de verificación copiado exclusivamente por el propietario.
No aceptar condiciones nuevas, migrar el número habitual ni configurar pagos
sin una autorización aparte. Mantener inicialmente el número de prueba.

## Trabajo pendiente para flujo autónomo completo

- Primer mensaje real recibido y visible en la bandeja móvil.
- Cola duradera de envíos, resultado desconocido ante timeout y estados de entrega.
- Plantillas aprobadas como tipo de envío, medios y paginación completa de plantillas.
- Consumidor del agente para la bandeja oficial: primero sugerencias revisadas,
  después autonomía delimitada por destinatarios, consentimiento y política.
- HTTPS estable, servicio supervisado, copias/retención y autorización por cliente
  para producción. La URL temporal no garantiza 24/7 y la llave compartida no es OAuth.

La configuración segura de lectura no equivale a una automatización completa.
