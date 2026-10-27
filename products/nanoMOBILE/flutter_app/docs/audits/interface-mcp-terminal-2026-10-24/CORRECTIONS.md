# Correcciones de interfaz, MCP y terminal — 24 de octubre de 2026

Se aplican correcciones de código para los 21 hallazgos del informe original. El diseño, los nombres públicos, las rutas y las claves de persistencia se conservan; la excepción intencional es sustituir la ejecución directa del diálogo MCP por inspección segura y retirar el botón de opciones que no tenía acción.

## Alcance y evidencia

- Alcance autorizado: código y capturas existentes. No se instalaron APKs ni se navegó o ejecutaron comandos/herramientas en el teléfono durante esta corrección.
- Sin pruebas automatizadas de la aplicación, según lo solicitado.
- Análisis estático de los 50 archivos Dart modificados o extraídos: **sin incidencias**. Registro: [corrections-scoped-analyze.log](corrections-scoped-analyze.log).
- Análisis global de `lib`: **0 errores, 1 advertencia y 59 avisos de estilo en otros archivos**. No se declara todo el repositorio libre de incidencias. Registro: [corrections-analyze.log](corrections-analyze.log).
- 52 archivos fuente de esta corrección, incluido C/Kotlin: todos menores a 200 líneas; máximo 169. Huellas y conteos: [corrections-sources.json](corrections-sources.json).
- Compilación y huella final del APK: [corrections-build.log](corrections-build.log) y [corrections-build.json](corrections-build.json).
- La captura disponible `terminal-hub-light.jpg` documenta el problema anterior. No constituye validación visual posterior.

## Hallazgos y corrección aplicada

| ID | Implementación | Cambio |
|---|---|---|
| MCP-01 | `mcp_tool_test_dialog.dart` | El diálogo es de inspección: no ejecuta herramientas ni sustituye el servidor. La ejecución continúa por el agente gobernado. |
| MCP-02 | `http_mcp_parser.dart` | Distingue resultado inválido, isError y éxito; conserva el diagnóstico remoto. |
| TERM-01 | `pty_session_registry.c` | Recoge únicamente PIDs PTY propietarios, reserva slots durante el cierre y conserva PIDs pendientes. EINTR no se interpreta como salida. |
| UI-01 | `nano_active_model_glass_card.dart; chat_screen_layout.part.dart` | Elimina modelo y 5.9 t/s ficticios; muestra estado observado y ausencia de medición. Nombre e indicadores se distribuyen de forma adaptable. |
| TERM-02 | `PtyChannelHandler.kt` | Despacha JNI por una cola acotada y ordenada con trabajador que expira en reposo, sin retener Activity. |
| TERM-03 | `terminal_screen.dart` | Solo reanuda polling cuando coinciden aplicación reanudada, ruta visible y pestaña seleccionada. |
| TERM-04 | `dashboard_plugin.dart` | Los inventarios sin fuente real se indican como no consultados, en lugar de mostrar ceros de listas de compatibilidad. |
| UI-02 | `terminal_coverflow_small.dart` | El título exterior a la portada usa el color semántico del tema, también en horizontal. |
| UI-03 | `terminal_coverflow_detail_portrait.dart` | Retira el botón de opciones vacío; conserva cierre y acceso a la ruta del módulo. |
| MCP-03 | `mcp_tool_test_dialog.dart` | Al separar inspección y ejecución, desaparecen el FutureBuilder y el resultado vacío que ocultaban errores. Muestra ausencias del catálogo explícitamente. |
| MCP-04 | `mcp_platform_status.dart; mcp_hub_platform_nodes.dart` | Consulta estado real de accesibilidad, con desconocido si no responde; el Core informa cobertura del catálogo, sin anunciar salud global. |
| MCP-05 | `http_mcp_catalog.dart` | Recorre cursores con límites de 20 páginas, 1000 herramientas y 30 s de lectura; rechaza ciclos y no publica una cobertura parcial como completa. |
| MCP-06 | `mcp_bounded_http.dart` | Lee JSON/SSE incrementalmente por ID; limita a 2 MiB y al plazo configurado, cancela su lectura al terminar y libera el transporte. |
| MCP-07 | `mcp_hub_graph.dart; mcp_hub_server_nodes.dart` | Calcula altura según nodos, asigna una banda por servidor y permite paneo sobre el lienzo completo sin restricciones del viewport. |
| MCP-08 | `mcp_connection_registry.dart; mcp_registry_discovery.dart` | Añade cierre idempotente del registro y desconexión de sus clientes; las respuestas tardías no notifican tras dispose. |
| MCP-09 | `mcp_skills_hub_screen.dart; mcp_hub_refresh.dart` | Protege setState con montaje, evita recargas duplicadas y recoge errores de refresco. Los diálogos comprueban montaje tras esperas. |
| MCP-10 | `mcp_store_connect.dart; mcp_store_connection_operation.dart` | Calcula conexión, fallos y herramientas por servidor; distingue conexión guardada de catálogo no disponible. Revierte solo su propia conexión ante fallos. |
| MCP-11 | `mcp_hub_journal.dart` | Presenta el journal como instantánea con fecha y actualización manual. |
| UI-04 | `terminal_coverflow_card.dart` | El visor respeta movimiento reducido mediante TickerMode y autoRotate, sin cambiar la manipulación directa. |
| TERM-05 | `terminal_screen_sessions.dart` | Conserva el ID de sesión activo al eliminar pestañas anteriores. Limita nuevas pestañas a 16 para concordar con el registro nativo. |
| MCP-12 | `local_device_inspection.dart` | Sensor ausente se muestra como no disponible; retira la evaluación de salud Óptimo que no se calculaba. |

## Mantenimiento y límites

Los archivos grandes afectados se separaron por responsabilidad: sesión, transporte y catálogo HTTP; datos del registro; esquemas y resultados locales; grafo, registro y tienda; sesiones y composición de terminal; portada e información por orientación. Las partes mantienen un único dueño del estado y comentarios de funcionamiento junto a los componentes.

La guía reutilizable se guarda en `products/.agents/skills/nano-mcp-terminal-integrity/SKILL.md` y su estructura se validó. No programa tareas ni concede permiso de ejecución.

Queda por comprobar manualmente, cuando se autorice el teléfono: legibilidad en ambos temas y orientaciones; apertura/cierre y cambio de pestañas al reanudar; estados de permiso reales; servidor paginado y SSE; cierre de pantalla durante una conexión. La compilación no demuestra ausencia de fallos de comportamiento ni mide rendimiento.

El límite de bytes y tiempo limita consumo local, no garantiza cancelación de una herramienta remota. Un hijo PTY que supera la espera acotada conserva su slot/PID para la siguiente recolección propietaria al asignar una sesión; no se afirma ausencia absoluta de procesos retrasados. Los sensores, inventarios y estados sin evidencia permanecen desconocidos o no consultados.
