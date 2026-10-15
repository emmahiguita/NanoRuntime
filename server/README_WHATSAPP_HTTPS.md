# HTTPS de prueba y configuración manual del webhook

Fecha: 13 de octubre de 2026.

## Estado observado

El usuario autorizó un túnel temporal de Cloudflare, exclusivamente al gateway
de WhatsApp del PC, y la gestión manual local de sus campos ocultos.
No se publicó la aplicación web, no se abrió el router/firewall y no se leyó ni
copió ninguna clave mediante herramientas.

Base HTTPS de esta sesión:

https://teens-multiple-milan-tap.trycloudflare.com

Callback de Meta:

https://teens-multiple-milan-tap.trycloudflare.com/api/v1/whatsapp/webhook

Es una URL temporal. Cambia al crear otro túnel y deja de funcionar al cerrar
cloudflared. No garantiza operación 24 horas ni debe presentarse como producción.
Para operación continua hace falta dirección estable y hosting sin suspensión.

## Protección aplicada antes de publicar

- Únicamente rutas conocidas del API WhatsApp; otras devuelven 404.
- Bandeja, plantillas y envío requieren la llave existente de Nano.
- Autenticación antes del parser JSON, para evitar procesar cuerpos sin autorización.
- La recepción conserva HMAC sobre bytes originales; el borde no reserializa JSON.
- Cuerpo máximo 4 MiB para webhook y 64 KiB para otras rutas.
- Lectura HTTP acotada a 10 segundos, además de límites existentes del servidor.
- Cabecera de firma ausente/malformada se rechaza antes de recibir el cuerpo.
- Documentación HTTP /docs, /redoc y /openapi.json no publicada.
- Cloudflared dirige solo a 127.0.0.1:8010; métricas solo en 127.0.0.1:20245.
- No se activó logging debug, que podría registrar cabeceras o URLs sensibles.
- Estas medidas no equivalen a rate limiting distribuido ni una auditoría SaaS completa.

## Comprobaciones reales

Con el gateway endurecido iniciado, la URL pública respondió:

| Ruta | Resultado |
| --- | --- |
| /api/v1/whatsapp/health | 200; salida configurada, webhook no configurado |
| /api/v1/whatsapp/conversations sin llave | 401 |
| /docs | 404 |
| /openapi.json | 404 |

TLS se verificó normalmente: no se omitió validación de certificados.
El indicador local meta_access_validated sigue false: no se deduce validez del token.
El indicador public_https_validated no se modifica por una comprobación aislada externa.

Después se detuvo exclusivamente la instancia iniciada por esta tarea para abrir
el panel privado. El panel debe poseer el gateway y arrancarlo tras guardar.
En la última captura del usuario aparece configuración guardada, App Secret vacío
y ningún servidor escuchando en 8010. Por ello la URL devuelve 502 mientras no se
pulse Iniciar con éxito. El túnel no reemplaza al gateway.

## Pasos manuales del propietario

1. En el panel Nano Desktop · Servidor de WhatsApp introduce el App Secret de la
   app Nano. No es el token temporal de WhatsApp. No lo envíes por chat.
2. Pulsa Guardar cifrado y después Iniciar. El panel debe informar arranque.
3. Copia tú el token de verificación del webhook mediante el campo oculto del panel.
4. En la configuración de webhooks de la app Meta introduce el callback HTTPS
   indicado arriba y ese token de verificación. Completa personalmente cualquier
   inicio de sesión o confirmación de permisos.
5. Verifica/guarda el callback y configura el campo messages y suscripción de la
   app a la WABA correspondiente. No migrar tu número habitual ni configurar pagos
   sin otra autorización explícita.
6. En Nano Mobile → Mensajes → Bandeja oficial de WhatsApp → Conexión segura,
   introduce la base HTTPS sin /api/... y copia tú la llave de acceso Nano.
7. No habilites el envío del agente por Cloud hasta revisar y autorizar ese cambio.
   Leer la bandeja y autorizar respuestas automáticas son operaciones distintas.

Llave Nano → cliente móvil. Token de verificación → Meta. App Secret y token de
acceso Meta → servidor. No intercambiar estos cuatro valores.
Los campos privados permanecen ocultos y de solo lectura. El portapapeles solo
se modifica si el propietario pulsa Copiar. No usar copia en un PC compartido;
limpia después el portapapeles y evita compartir capturas con secretos visibles.

## Si aparece un error

- Diagnóstico corregido: Comprobar Meta diferencia error de credencial, permisos,
  parámetros/activos, red/TLS y respuesta ilegible usando códigos de Meta.
  No muestra el cuerpo remoto crudo ni copia sus mensajes con datos privados.
- El transporte Graph no sigue redirecciones de credenciales; conserva resultados
  reales y elimina URLs paging.next/previous que pueden incluir access_token.
  El panel consulta loopback directamente, sin reenviar la llave por proxies.
- Se reprodujo un fallo específico del panel pythonw: Uvicorn intentaba consultar
  isatty() en stdout inexistente. El arranque ahora configura handlers sin consola;
  la ejecución desde terminal conserva sus registros. Los errores del panel se
  clasifican con textos seguros, sin mostrar credenciales ni excepciones crudas.
- La reserva del puerto se libera también si falla la construcción de Uvicorn,
  antes de entregar recursos al controlador. Reabrir el panel carga la corrección.
- Si se pegó un token Meta en un chat, revocarlo y reemplazarlo únicamente en el
  formulario privado. Esta corrección no demuestra la validez de la credencial.
- 502 público + puerto local sin listener: iniciar el gateway, no renovar el modelo.
- 401: llave Nano ausente/incorrecta; no se resuelve pegando el token Meta al móvil.
- 503 de webhook o webhook_configured=false: revisar App Secret y configuración.
- Callback rechazado: comprobar gateway iniciado, URL actual y token de verificación.
- Error en Comprobar Meta: revisar credencial y permisos remotos; un arranque local
  no confirma acceso Meta.
- Error de arranque del panel: copiar solo el texto del aviso para diagnosticar;
  no ejecutar otra instancia ni desinstalar Nano.

Cerrar el panel detiene su propio gateway. El proceso cloudflared de esta prueba
está separado; detener únicamente esa instancia cuando termine la prueba.
No se instaló autoinicio ni se cambió suspensión, firewall, DNS o cuenta Cloudflare.

## Pendiente de validar

Todavía no se verificaron handshake guardado en Meta, suscripción efectiva,
recepción de un mensaje real, conexión autenticada desde el móvil ni entrega.
No se enviaron mensajes, replays o eventos ficticios para aparentar funcionamiento.

Comprobación posterior del 13 de octubre: el panel PID 33572 posee el puerto 8010.
El estado local y el HTTPS de esta sesión respondieron 200: outgoing_configured=true,
webhook_configured=false y meta_access_validated=false. Esto prueba arranque y
transporte, no validez del token, suscripción ni recepción. El propietario confirmó
haber revocado el token expuesto y guardado otro; su valor no se inspeccionó.

Las correcciones de diagnóstico pasan Ruff, AST e importación, con archivos menores
a 200 líneas. Se conservó el proceso activo hasta que el propietario confirmó
Detener; después se reabrió el panel y cargó diagnóstico nuevo y MCP.

La publicación inicial de MCP se detuvo en revisión de seguridad. Posteriormente
el propietario autorizó específicamente el host de esta sesión y las lecturas
protegidas con llave Nano. Se implementó y publicó el adaptador de lectura.
El panel corregido PID 30564 posee el gateway: health 200 y MCP sin llave 401
tanto en loopback como por HTTPS. El propietario confirmó handshake MCP autenticado
con cuatro herramientas y lectura real de Meta correcta desde sus botones privados.
No se instalaron QR, automatizaciones de envío, herramientas de Facebook o Instagram.
Consulta [alcance, conexión y pendientes de MCP](README_WHATSAPP_MCP.md).

## Referencia primaria

[Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/):
URL temporal, límites y ausencia de garantías de disponibilidad.
