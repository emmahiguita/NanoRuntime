# Implementación del flujo manual de Nano Negocio

18 de octubre de 2026. Continuación autorizada tras la auditoría. El dueño confirmó
que 3203527283 y 3225133665 son sus líneas empresariales y no están registradas en Meta.

## Cambios aplicados en código

- Centro de Mensajes y Canales de Nano Negocio abren el selector de las dos líneas.
  Cada bandeja conserva su línea al abrir conversaciones y plantillas.
- Conexiones cifradas independientes mediante alias `line_3203527283` y
  `line_3225133665`. Una línea nueva no hereda claves de la anterior y desconectarla
  no borra la conexión anterior. Se mantiene acceso explícito a la configuración legacy.
- Gateway: selección de activos por `X-Nano-Line-ID`, validación del alias y
  restauración del ámbito al terminar la petición. Las líneas son del mismo dueño:
  esto no constituye una plataforma multiempresa con credenciales aisladas por tenant.
- Webhook firmado admite lotes de las líneas registradas, rechaza ámbitos ajenos
  y conserva la persistencia/deduplicación originales.
- Historial admite echo, conserva dirección y diferencia eventos webhook de una
  aceptación de envío por Meta. El cursor espera confirmación de escritura local.
- Editor manual en cada conversación: texto, plantillas aprobadas y selección
  de un archivo desde Biblioteca de Nano o teléfono. Lectura por tramos, máximo 6 MB.
- Plantillas con parámetros numéricos de texto en cabecera/cuerpo: exige valores
  reales del usuario. Plantillas con parámetros especiales de multimedia, botones
  dinámicos o nombres de variables requieren soporte adicional; no se inventan valores.
- Transporte oficial para texto, plantilla, imagen, audio, vídeo y documento.
  Archivo se sube a Meta, obtiene ID real y solo después se envía al destinatario.
- Registro aditivo de solicitudes manuales: ID estable por intento del editor,
  reserva en SQLite antes del POST y reutilización del WAMID si ya fue aceptado.
  Un resultado incierto no dispara reenvío. No hay reintentos automáticos.
- Salientes aceptados se incorporan al historial con evidencia de respuesta de Meta.
  Los estados enviados/entregados/leídos/fallidos proceden de eventos oficiales.
- Perfil/cuenta: portada adaptable, controles nativos, nombre con altura natural,
  edición de imagen y cabecera fuera del área de la barra. Sin insignia de verificación
  fija ni etiqueta de bóveda segura sin evidencia.

## Protección del historial existente

La primera propuesta de reconstruir la tabla fue rechazada por revisión automática.
Se sustituyó por una alternativa sin DROP, ALTER o DELETE: echo conserva dirección
en el payload y utiliza el esquema existente. Se añade únicamente una tabla de
solicitudes salientes y un índice de consulta al ejecutar normalmente el gateway.
No se ejecutó ninguna migración ni se abrió la base de datos durante este trabajo.

## Qué falta fuera del código

1. Registrar ambas líneas en Meta y obtener sus Phone Number ID y WABA ID reales.
2. Configurar credenciales privadas del gateway y HTTPS accesible para webhooks.
3. Establecer el mapa público `META_WHATSAPP_LINES_JSON` en el entorno del servidor:
   cada alias se relaciona con `waba_id` y `phone_number_id` registrados.
   No introducir aquí los teléfonos como si fueran IDs de Meta.
4. Suscribir la aplicación/WABA y comprobar recepción oficial por cada línea.
5. Configurar URL y claves Nano de lectura/envío en la conexión móvil correspondiente.
6. Confirmar manualmente respuesta y estados reales, con destinatario y contenido
   autorizados. No se realizaron envíos ni llamadas autenticadas a Meta.

La configuración anterior puede conservarse como default. Las dos líneas comparten
aplicación y credenciales Meta del servidor: requieren autorización sobre ambos activos.
El mapa de IDs no registra números, verifica propiedad, concede permisos ni los activa.

## Límites que permanecen explícitos

- Las líneas siguen pendientes de registro: no están operativas por añadir su nombre a la UI.
- No se activaron respuestas automáticas, trabajos residentes ni tareas de envío.
- No se publicaron Flows. El constructor anterior no obtiene un Flow ID real ni
  publica un formulario; esa capacidad no se presenta como terminada.
- El editor es manual; no se añadió generación automática de respuestas en la bandeja oficial.
- Se muestran estados del proveedor disponibles; aceptación no significa entrega.
- No se verificó el ciclo completo en Android/Meta ni rendimiento con adjuntos reales.
- La intención de envío incierta se conserva en la sesión del editor y el gateway;
  no se implementó restauración del borrador móvil después de cerrar la app.

## Verificación

Revisión estática de Flutter y sintaxis Python. Sin suites automatizadas, sin arrancar
el gateway, sin consultar credenciales privadas y sin interactuar con el teléfono.
Modelos y runtimes conservados. APK fullSideload release compilado correctamente (101,9 MB). No instalado en el teléfono.

Fuentes de contrato consultadas: [documentación oficial de Meta en Postman](https://www.postman.com/meta/whatsapp-business-platform/documentation/wlk6lh4/whatsapp-cloud-api?entity=request-13382743-eb9a6721-1056-4db2-b00a-2290e04b5b5d),
[plantillas](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/api-reference/messages/template/),
[documentos](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/api-reference/messages/document/).

## Inspección de Meta Business Suite

Portafolio Nano Labs, ID 1268671718759868. Cuenta de prueba WABA 2639298723174280 con número de prueba; cuenta devemmai ID 1741855147139109 vinculada a WhatsApp Business, con una línea distinta a las solicitadas y estado sin conexión. Ninguna de las dos líneas solicitadas aparece en estas cuentas. No se modificó esa línea existente ni se activó facturación.


## Revisión de aplicación segura de la API

Aplicación Meta Nano ID 2573540473149534, propiedad de Nano Labs. El panel muestra
whatsapp_business_management y whatsapp_business_messaging como «Listo para la prueba»;
ese estado no demuestra autorización operativa de las dos líneas empresariales.
La sección de producción permanece cargando tanto desde el menú como desde el enlace
directo publicado por Meta. No se crearon credenciales ni se ampliaron permisos.

Controles confirmados por lectura del código actual:
- Claves Nano separadas de lectura, envío y administración; comparación constante.
- Autenticación antes del procesamiento del cuerpo y rutas publicadas mediante lista cerrada.
- Firma SHA-256 HMAC sobre bytes originales del webhook y validación del challenge.
- Activos de cada línea explícitos, rechazando eventos de líneas no configuradas.
- Cliente móvil exige HTTPS y rechaza redirecciones con credenciales.
- Límites de cuerpo y tiempo, cancelación de solicitudes y reserva durable del envío.

Pendiente antes de considerar producción completa y segura:
- Registro y verificación de propiedad de ambos números; IDs reales por línea.
- Token de servidor con acceso mínimo a esos activos, App Secret y token de webhook
  guardados fuera del APK; no se inspeccionaron valores privados.
- Dominio HTTPS real, suscripción messages y comprobación del destino del webhook.
- Configurar límites de solicitudes/concurrencia en el despliegue; los límites de tamaño
  y tiempo del middleware no equivalen a protección contra volumen de solicitudes.
- Revisar recuperación y retención del historial y validar manualmente recepción,
  aceptación y estados oficiales con autorización del dueño.

No se certifica seguridad total ni funcionamiento extremo a extremo mediante esta
revisión estática. Sin pruebas automatizadas, mensajes enviados ni facturación activada.
