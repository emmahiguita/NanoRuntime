# Nano Meta WhatsApp · MCP de lectura

Fecha: 13 de octubre de 2026.

## Alcance autorizado

El propietario autorizó expresamente la consulta de conversaciones, mensajes
recibidos y plantillas mediante el túnel de prueba indicado abajo, protegido con
la llave Nano. Cloudflare transporta los datos; solo compartir esa llave con un
cliente de confianza y autorizado. El asistente no extrajo ni copió credenciales.

Este es un adaptador de Nano basado en el SDK oficial del protocolo MCP,
no un servidor de WhatsApp publicado por Meta ni una conexión por WhatsApp Web/QR.
La integración saliente sigue usando Meta Graph API oficial.

## Conexión del cliente

Endpoint local: http://127.0.0.1:8010/api/v1/whatsapp/mcp

Endpoint HTTPS de esta sesión:
https://teens-multiple-milan-tap.trycloudflare.com/api/v1/whatsapp/mcp

- Transporte: Streamable HTTP; respuestas JSON, sin SSE residente ni sesiones persistentes.
- Nano Mobile ya tiene un cliente de este transporte: introduce el endpoint completo
  y la llave Nano manualmente en su conexión MCP. El cliente la envía como Bearer.
- Otros clientes pueden usar Authorization: Bearer con esa llave o X-Nano-API-Key,
  pero no ambas cabeceras. Nunca usar el token Meta en el cliente MCP.
- La llave histórica ahora es exclusivamente de lectura: no puede enviar ni
  administrar plantillas por REST. Se generan llaves separadas para esos permisos.
  Ver [migración, cliente móvil y validación](README_WHATSAPP_PERMISSIONS.md).
- No se implementó OAuth ni alta automática en Claude/Desktop. El cliente elegido
  debe admitir configuración manual de cabecera/credencial; no se comprobó aquí.
- Host público exacto mediante NANO_WHATSAPP_PUBLIC_HOST al iniciar el panel.
  Se configuró únicamente teens-multiple-milan-tap.trycloudflare.com para esta sesión.
  No hay comodín *.trycloudflare.com ni protección DNS desactivada.

El hostname del túnel es temporal. Cambiarlo requiere actualizar el host permitido
y el endpoint del cliente; no hay garantía de servicio continuo/producción.

## Herramientas reales

| Herramienta | Fuente y alcance |
| --- | --- |
| whatsapp_get_conversations | Último mensaje recibido por interlocutor, desde SQLite del webhook |
| whatsapp_get_messages | Mensajes recibidos del interlocutor exacto, paginados |
| whatsapp_get_changes | Eventos persistidos después de un cursor, incluidos estados recibidos |
| whatsapp_get_templates | Página inicial de plantillas del WABA consultada en Meta |

Historial admite limit 1..100 y cursores de enteros signed de 64 bits. Los mensajes
usan un peer_id numérico exacto. El ámbito WABA/número lo impone el servidor,
no los argumentos del modelo. El adaptador reutiliza lector y controles del REST;
no duplica base de datos, importadores ni workers.

No hay herramientas para enviar, editar o borrar; tampoco contactos, Facebook
o Instagram ficticios. Las rutas REST anteriores no cambian sus permisos ni
se habilitan automáticamente por configurar MCP. Los hints readOnly describen
el catálogo, pero la ausencia de operaciones de escritura es la protección real.

No importa conversaciones previas de WhatsApp ni mensajes que Meta no entregó
al webhook. No confundir una conexión MCP válida con un historial completo.
La lectura de plantillas conserva componentes y estados reales, pero sigue siendo
la página inicial: no se implementó paginación adicional de plantillas en este sprint.

## Seguridad y ciclo de vida

La autenticación del gateway precede al parser JSON y al SDK. Se mantienen los
límites de cuerpo/lectura y se rechazan credenciales duplicadas o ausentes.
Los headers de acceso no se registran. El transporte Graph no sigue redirecciones
con Authorization y omite paging.next/previous que pueden contener access_token.

El lifespan compartido inicializa SQLite y SDK y los cierra al detener el gateway.
Cada arranque crea un session manager nuevo: el SDK no admite reutilizarlo después
de su cierre. MCP no abre otro puerto ni lanza procesos hijos.

## Comprobaciones y pendientes

- Ruff, AST e importación correctos; archivos modificados menores a 200 líneas.
- Catálogo inspeccionado: exactamente las cuatro herramientas, todas de lectura.
- Gateway local y HTTPS: health 200; MCP sin llave: 401 en ambos destinos.
- El propietario pulsó Comprobar MCP y confirmó "MCP autenticado: 4 herramientas
  de lectura". Es un handshake HTTP local autenticado y tools/list del SDK real,
  sin consultar chats ni Meta y sin exponer la llave a herramientas del asistente.
- El propietario pulsó Comprobar Meta y confirmó "Lectura real de Meta correcta".
  Prueba esa consulta real de plantillas, no recepción ni entrega de mensajes.
- La última comprobación técnica informa webhook_configured=false. Falta App Secret,
  handshake de webhook guardado en Meta, suscripción efectiva y primer mensaje real.
- Aún no se comprobó un cliente externo autenticado por HTTPS, el cliente móvil,
  la selección de herramientas por modelos ni una conversación completa del agente.

No se ejecutaron suites de tests, envíos, mensajes ficticios o replays.

## Referencia primaria

[SDK Python MCP v1.28.1](https://github.com/modelcontextprotocol/python-sdk/tree/v1.28.1):
FastMCP, Streamable HTTP y gestión de ciclo de vida. Se fija la versión instalada
en requirements-whatsapp.txt; no se migró silenciosamente a la línea v2.
