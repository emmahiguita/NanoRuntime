# Graph Report - server  (2026-10-13)

## Corpus Check
- 35 files · ~17,302 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 406 nodes · 689 edges · 20 communities (19 shown, 1 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 53 edges (avg confidence: 0.71)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `011b359e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- whatsapp_webhook_api.py
- whatsapp_templates_api.py
- main.py
- whatsapp_webhook_api.py
- whatsapp_webhook_normalizer.py
- Nano · recepción oficial de WhatsApp (sprint 2)
- ConnectionManager
- WebhookInbox
- Nano Desktop · gateway local de WhatsApp
- LocalGatewayPanel
- HTTPS de prueba y configuración manual del webhook
- gateway_health
- Bandeja oficial: lectura y sincronización
- MetaWebhookScope
- whatsapp_webhook_normalizer.py
- whatsapp_panel_view.py
- whatsapp_graph_transport.py
- Estados visibles del servidor de WhatsApp
- whatsapp_gateway_health.py
- McpGatewayEndpoint

## God Nodes (most connected - your core abstractions)
1. `MetaWebhookScope` - 17 edges
2. `LocalGatewayPanel` - 16 edges
3. `ConnectionIndicators` - 13 edges
4. `_graph_request()` - 12 edges
5. `SqliteWhatsAppHistory` - 12 edges
6. `load_settings()` - 12 edges
7. `CheckResult` - 11 edges
8. `GatewayController` - 11 edges
9. `receive_webhook()` - 11 edges
10. `authorize_gateway()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `LocalGatewayPanel` --uses--> `CheckResult`  [INFERRED]
  whatsapp_local_panel.py → whatsapp_check_result.py
- `LocalGatewayPanel` --uses--> `GatewayController`  [INFERRED]
  whatsapp_local_panel.py → whatsapp_local_controller.py
- `LocalGatewayPanel` --uses--> `PanelView`  [INFERRED]
  whatsapp_local_panel.py → whatsapp_panel_view.py
- `PanelView` --uses--> `ConnectionIndicators`  [INFERRED]
  whatsapp_panel_view.py → whatsapp_panel_status.py
- `PanelView` --uses--> `PrivateConnectionFields`  [INFERRED]
  whatsapp_panel_view.py → whatsapp_private_fields.py

## Import Cycles
- None detected.

## Communities (20 total, 1 thin omitted)

### Community 0 - "whatsapp_webhook_api.py"
Cohesion: 0.16
Nodes (21): ValueError, apply_settings(), data_directory(), load_settings(), prepare_directory(), Path, Credenciales del gateway local: disco privado, DPAPI y escritura atómica., Carga secretos únicamente en el proceso del gateway, antes del arranque. (+13 more)

### Community 1 - "whatsapp_templates_api.py"
Cohesion: 0.18
Nodes (21): HTTPException, _graph_request(), Una llamada acotada, sin reintentos de envíos que puedan duplicar mensajes., create_template(), delete_template(), list_templates(), _phone_number_id(), Any (+13 more)

### Community 2 - "main.py"
Cohesion: 0.13
Nodes (19): async_gpu_poll_loop(), async_inference_loop(), async_telemetry_broadcast_loop(), _check_metrics_auth(), ConnectionManager, get_real_system_snapshot(), prometheus_metrics(), Any (+11 more)

### Community 3 - "whatsapp_webhook_api.py"
Cohesion: 0.06
Nodes (49): Connection, InboxDependency, _inbox(), Request, Entrada oficial del gateway; no envía mensajes ni ejecuta el LLM en el webhook., El handler no conoce SQLite; ausencia de almacenamiento nunca es éxito., Limita la lectura incluso sin Content-Length; rechaza compresión no soportada., JSON estricto: NaN e Infinity no pertenecen al protocolo JSON de Meta. (+41 more)

### Community 4 - "whatsapp_webhook_normalizer.py"
Cohesion: 0.14
Nodes (19): HTTPRedirectHandler, CheckResult, Resultado público de una comprobación: evidencia y texto, nunca credenciales., El servicio declara éxito/pendiente/error; la vista no adivina por frases., NoCredentialRedirect, Impide reenviar Authorization o la llave Nano a otro destino por redirección., check_meta_readonly(), check_meta_result() (+11 more)

### Community 5 - "Nano · recepción oficial de WhatsApp (sprint 2)"
Cohesion: 0.11
Nodes (16): Ciclo de vida y límites comprobables, Fuentes primarias, Iniciar en este PC, Lo que sigue pendiente, Nano Desktop · gateway local de WhatsApp, Arranque, Límite de alcance, Nano · gestor de plantillas oficiales de WhatsApp (+8 more)

### Community 6 - "ConnectionManager"
Cohesion: 0.09
Nodes (18): Config, Server, socket, GatewayController, Ciclo de vida del gateway del panel: un solo hilo, sin hijos huérfanos., Distingue hilo vivo de servidor listo; la UI puede mostrar el arranque real., Evita doble arranque y deja el trabajo de disco/red fuera del hilo visual., Liberación explícita del socket incluso si Uvicorn no alcanza a iniciar. (+10 more)

### Community 7 - "WebhookInbox"
Cohesion: 0.17
Nodes (13): FastAPI, FastMCP, Autenticación común del gateway: la llave de Nano no es el token de Meta., Botón de diagnóstico MCP: el propietario lo activa en el panel privado., create_mcp(), gateway_lifespan(), _guard(), Adaptador MCP de lectura sobre el gateway oficial, no un WhatsApp Web/QR. (+5 more)

### Community 8 - "Nano Desktop · gateway local de WhatsApp"
Cohesion: 0.07
Nodes (40): Cursor, ge, le, Limit, pattern, Query, Response, changes() (+32 more)

### Community 9 - "LocalGatewayPanel"
Cohesion: 0.11
Nodes (14): LocalGatewayPanel, main(), Tk, Validación manual de protocolo y herramientas; nunca consulta mensajes ni Meta., Consulta estado de configuración; nunca fabrica una entrega ni firma eventos., Espera cierre cooperativo de las operaciones; nunca deja un servidor hijo zombi., Los IDs de prueba se pasan explícitamente, sin hacerlos defaults de otras empres, Solo configuración técnica: no inventa conversaciones, modelos ni permisos de Me (+6 more)

### Community 10 - "HTTPS de prueba y configuración manual del webhook"
Cohesion: 0.08
Nodes (23): Comprobaciones reales, Estado observado, HTTPS de prueba y configuración manual del webhook, Pasos manuales del propietario, Pendiente de validar, Protección aplicada antes de publicar, Referencia primaria, Si aparece un error (+15 more)

### Community 11 - "gateway_health"
Cohesion: 0.08
Nodes (19): ConnectionIndicators, Indicadores permanentes; verde solo con evidencia y alertas accesibles por texto, Representa estado local y últimas comprobaciones sin sondear Meta ni leer secret, Crea cuatro estados separados: proceso, lectura Meta, MCP y recepción pendiente., Solo repinta cambios; el texto acompaña al color para no depender de él., Un reinicio/cambio de configuración invalida éxitos de la sesión anterior., Tener secreto no demuestra recepción: configuración sigue en ámbar., Verde depende del hilo vivo y Uvicorn iniciado, no del último mensaje del panel. (+11 more)

### Community 12 - "Bandeja oficial: lectura y sincronización"
Cohesion: 0.25
Nodes (7): Bandeja oficial: lectura y sincronización, Conexión móvil, Diseño y mantenimiento, Qué significa el historial, Rutas nuevas, Siguiente paso, Validación de esta implementación

### Community 13 - "MetaWebhookScope"
Cohesion: 0.22
Nodes (7): _allowed(), GatewayBoundary, Borde HTTP del gateway: autentica antes de leer JSON y limita cuerpos y espera., Errores breves sin registrar cabeceras, llaves ni contenido de mensajes., Lista cerrada: rutas nuevas requieren una decisión de publicación explícita., Middleware ASGI sin servidor, tareas residentes ni almacenamiento adicional., El lifespan pasa intacto; HTTP no autorizado no alcanza parsers ni Graph.

### Community 14 - "whatsapp_webhook_normalizer.py"
Cohesion: 0.20
Nodes (10): authenticate_gateway(), authorize_gateway(), Compatibilidad de las lecturas existentes; nunca concede escritura por defecto., Cada ruta declara su permiso; el cliente/modelo no puede elegir su propio rol., _check(), check_mcp_readonly(), check_mcp_result(), Handshake y catálogo por HTTP real; no envía, lee chats ni consulta Meta. (+2 more)

### Community 15 - "whatsapp_panel_view.py"
Cohesion: 0.25
Nodes (5): PanelView, Vista del panel: estados y acciones fijos, formulario desplazable sin recortes., Componentes existentes con callbacks originales; no crea otro servidor o configu, Deshabilita acciones incompatibles; no bloquea el hilo visual ni envía consultas, Campos privados del panel: solo el usuario copia manualmente valores ocultos.

### Community 16 - "whatsapp_graph_transport.py"
Cohesion: 0.33
Nodes (5): _failure(), _meta_error(), Transporte Graph compartido: respuestas reales y diagnóstico sin secretos., Solo conserva códigos numéricos y banderas, nunca el cuerpo/error remoto crudo., Mantiene detail como texto para el móvil; diagnóstico numérico separado en heade

### Community 17 - "Estados visibles del servidor de WhatsApp"
Cohesion: 0.40
Nodes (4): Estados visibles del servidor de WhatsApp, Indicadores permanentes, Mantenimiento y evidencia, Vista y comportamiento

### Community 18 - "whatsapp_gateway_health.py"
Cohesion: 0.40
Nodes (4): gateway_health(), Request, Diagnóstico local sin revelar credenciales ni confundir arranque con conexión Me, Mide disponibilidad del proceso y configuración, NO validez remota del token.

## Knowledge Gaps
- **42 isolated node(s):** `Rutas nuevas`, `Qué significa el historial`, `Conexión móvil`, `Diseño y mantenimiento`, `Validación de esta implementación` (+37 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ConnectionIndicators` connect `gateway_health` to `whatsapp_panel_view.py`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Why does `LocalGatewayPanel` connect `LocalGatewayPanel` to `whatsapp_webhook_normalizer.py`, `ConnectionManager`, `whatsapp_panel_view.py`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Why does `GatewayController` connect `ConnectionManager` to `LocalGatewayPanel`, `whatsapp_webhook_normalizer.py`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Are the 18 inferred relationships involving `HTTPException` (e.g. with `_check_metrics_auth()` and `authorize_gateway()`) actually correct?**
  _`HTTPException` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `MetaWebhookScope` (e.g. with `HistoryCursorExpired` and `WhatsAppHistoryReader`) actually correct?**
  _`MetaWebhookScope` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `LocalGatewayPanel` (e.g. with `CheckResult` and `GatewayController`) actually correct?**
  _`LocalGatewayPanel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `ConnectionIndicators` (e.g. with `PanelView` and `ScrollableForm`) actually correct?**
  _`ConnectionIndicators` has 2 INFERRED edges - model-reasoned connections that need verification._