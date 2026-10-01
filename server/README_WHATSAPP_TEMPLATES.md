# Nano · gestor de plantillas oficiales de WhatsApp

Este servicio independiente consulta y administra plantillas de un WABA mediante la WhatsApp Business Platform Cloud API. No activa OpenWA, no simula respuestas y no marca una plantilla como aprobada por cuenta propia.

## Requisitos reales

- Una Meta App con WhatsApp configurado, un WABA y un token de acceso emitido por Meta con `whatsapp_business_management`.
- Los valores `META_WHATSAPP_ACCESS_TOKEN`, `META_WHATSAPP_WABA_ID` y `META_GRAPH_API_VERSION` configurados solo en el entorno del servidor.
- Para envío Cloud, también `META_WHATSAPP_PHONE_NUMBER_ID` y permiso de Meta `whatsapp_business_messaging`.
- Una llave aleatoria privada `NANO_WHATSAPP_API_KEY` de al menos 32 caracteres. El móvil guarda únicamente esta llave de Nano usando el almacenamiento seguro del sistema.
- Servicio accesible mediante HTTPS. En producción, terminar TLS en un proxy o plataforma administrada; no exponer Uvicorn HTTP directamente a Internet.

## Arranque

Desde la raíz del repositorio, con el entorno Python que ya ejecuta FastAPI:

```powershell
$env:NANO_WHATSAPP_API_KEY = "<llave privada aleatoria de 32+ caracteres>"
$env:META_WHATSAPP_ACCESS_TOKEN = "<token de Meta>"
$env:META_WHATSAPP_WABA_ID = "<id WABA>"
$env:META_WHATSAPP_PHONE_NUMBER_ID = "<id del número registrado en Cloud API>"
$env:META_GRAPH_API_VERSION = "v<versión Graph soportada por tu app>"
python -m uvicorn server.whatsapp_templates_api:app --host 127.0.0.1 --port 8010
```

Publica el servicio detrás de HTTPS y configura en Nano Negocio la URL base HTTPS y `NANO_WHATSAPP_API_KEY`. No guardes el token de Meta en el teléfono.

## Operaciones implementadas

| Método | Ruta | Operación real |
|---|---|---|
| GET | `/api/v1/whatsapp/templates` | Lee la página inicial de plantillas y estados desde el WABA |
| POST | `/api/v1/whatsapp/templates` | Envía una nueva plantilla a Meta para su procesamiento |
| PUT | `/api/v1/whatsapp/templates/{id}` | Envía a Meta la edición de categoría/componentes |
| DELETE | `/api/v1/whatsapp/templates/{id}?name=...` | Elimina la plantilla remota mediante ID y nombre |
| POST | `/api/v1/whatsapp/messages` | Envía texto por el número registrado en Cloud API |

Todas requieren `X-Nano-API-Key`. Meta conserva la autoridad sobre componentes admitidos, elegibilidad, aprobación y estado final; los errores remotos se devuelven como error, no como éxito local. El editor usa `components` JSON para no limitar encabezados, medios, botones ni formatos soportados por la versión activa de Meta.

En el diálogo de conexión del Agente Negocios se puede conservar el canal de WhatsApp instalado o seleccionar Meta Cloud. La selección Cloud envía texto real por el gateway y muestra el ID de Meta; no hace fallback al canal local. Meta puede rechazar el envío si falta consentimiento, el destinatario/activo no es válido o se requiere una plantilla aprobada fuera de la ventana de atención. El canal de app instalada no confirma entrega.

## Límite de alcance

Este módulo administra plantillas y envío de texto saliente; todavía no recibe conversaciones por webhook ni convierte respuestas libres en plantillas aprobadas. Cloud requiere configuración real de Meta, HTTPS público y reglas de consentimiento/ventana; sin esos datos, las llamadas devuelven error y no simulan éxito. El canal instalado conserva su comportamiento original.

Las instrucciones de tarifa, límites y elegibilidad cambian con el tiempo; consulta los documentos oficiales de Meta antes de configurar producción. No se copian valores de precio o throughput desde los informes adjuntos.
