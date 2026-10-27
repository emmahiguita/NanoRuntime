# Integración MCP, agente y terminal — 24 de octubre de 2026

Se implementaron las correcciones de los diez hallazgos de la auditoría anterior y se generó `fullSideloadDebug`. Esto acredita compilación y revisión estática; no acredita que todas las herramientas o modelos hayan ejecutado inferencia en el teléfono.

## Cambios de comportamiento

| Hallazgo | Corrección aplicada | Evidencia principal |
|---|---|---|
| F01: categorías MCP sin contrato semántico | Contratos canónicos de lectura, dispositivo, escritura y privilegios; ausencia de contrato deja de convertirse en observación. | `semantic_mcp_policies.dart`, `tool_definition.dart`, `tool_policy_engine.dart` |
| F02: permisos derivados de pistas remotas | Clasificación local por identidad interna reservada; las anotaciones de un servidor externo no conceden permiso de lectura automática. | `mcp_local_tool_policy.dart` |
| F03: pérdida de mayúsculas cnónicas | El parser resuelve alias sin convertir `mcp.externalWrite` en una herramienta desconocida. | `agent_tool_protocol.dart`, `ToolRegistry.canonicalName` |
| F04: argumentos vacíos o sin validar | Candidatos conservan JSON/rutas escritos explícitamente; el manejador valida el contrato completo antes del efecto. | `mcp_candidate_arguments.dart`, `mcp_schema_validator.dart` |
| F05: contenido alterado al escribir | Se preservan espacios y saltos de línea; `printf` con comillas evita interpretar contenido como shell. La comprobación usa SHA-256 y falla si no puede leer el hash. | `linux_fs_write.dart`, `linux_action_verifier.dart` |
| F06: procesos anunciados sin evidencia | Estados solicitud/salida observada/parada pendiente/finalización. Una señal no demuestra salida; no se inventa PID ni se anuncian tareas terminadas como pendientes. | `linux_process_supervisor.dart`, `linux_process_observation.dart` |
| F07: éxito inferido por prefijos | Estado y texto viajan separados hasta el dispatcher y el journal. Un texto `[INFO]` puede ser un resultado válido. | `mcp_result_presenter.dart`, `tool_execution_report.dart`, `plan_irreversible.dart` |
| F08: binarios tratados como texto entendido | La presentación identifica el tipo y MIME y declara que el adjunto no fue interpretado. Se quitó el sobre JSON completo usado como contenido estructurado. | `http_mcp_parser.dart`, `mcp_result_presenter.dart` |
| F09: ficha sin límites adaptativos | Hoja acotada a la pantalla con desplazamiento; admite metadatos largos sin una columna de altura ilimitada. | `mcp_graph_node_details.dart` |
| F10: JSON parcial reconstruido | Escáner consciente de comillas/escapes; se rechaza el plan completo si contiene una llamada malformada. No se fabrican argumentos faltantes. | `agent_json_payload.dart`, `agent_tool_protocol.dart` |

La validación usa `json_schema` 5.2.2, su biblioteca mantenida, en un isolate con plazo de un segundo. No se resuelven referencias externas por red. Se limitan esquema, argumentos y errores mostrados. La versión discontinuada `json_schema2` usada durante la implementación fue retirada antes del APK final. Fuente del paquete: https://pub.dev/packages/json_schema

## Qué permite MCP con Linux

El conector `nano-linux` es interno, en proceso; no es un servidor stdio ni comparte la sesión PTY abierta en Terminal. Su catálogo pasó de seis a doce operaciones con esquema explícito:

- `fs.list`, `fs.read`, `fs.stat`: consultar carpetas, texto y metadatos.
- `fs.write`, `fs.copy`, `fs.move`: guardar texto, copiar o mover con autorización y la verificación disponible del motor. La comprobación de copia/movimiento confirma destino; no promete comparación byte a byte.
- `archive.create`: preparar tar/tar.gz y comprobar que puede leerse su índice; esto no equivale a comparar cada archivo de origen.
- `git.status`, `git.diff`, `git.log`: revisar cambios e historial cuando Git esté instalado y el repositorio exista.
- `process.list`, `process.inspect`: observar la tabla visible para Nano y las tareas rastreadas por su supervisor. No supervisa todos los procesos de Android ni las sesiones PTY independientes.

Las rutas del catálogo deben ser absolutas. Lectura: máximo 64 KiB; escritura literal: máximo 64 KiB en UTF-8, sin NUL. Resultados extensos se señalan como parciales. No se publicó extracción de tar ni ejecución genérica de comandos desde este catálogo: requieren una revisión específica adicional.

Ventajas concretas: preparar respaldos autorizados, organizar archivos de trabajo y revisar proyectos sin que el modelo invente Bash. La terminal manual sirve para trabajar con los programas instalados; MCP permite al agente solicitar operaciones concretas y conservar su resultado. Esto no concede root, permisos adicionales de Android, RAM adicional ni comprensión visual a un modelo de texto.

## Interfaz y uso

La vista inicial muestra herramientas agrupadas por servidor, buscador, descripciones y necesidad de confirmación. El grafo permanece como alternativa. Las pestañas distinguen Herramientas, Registro y Conexiones; el registro conserva su condición de instantánea manual.

Se reutilizan iconos Nano por familia funcional. La configuración del modelo de conversación indica que sus credenciales no vinculan servidores MCP. La plantilla de WhatsApp Business deja de marcarse como integración verificada y aclara que el flujo de inicio de sesión OAuth no está integrado.

Al tocar una herramienta se pueden consultar sus argumentos, completar un objeto JSON y validar/copiar el comando. Copiar no ejecuta. Enviar ese comando humano al agente autoriza esa llamada exacta, conforme al comportamiento existente de los comandos `@`. Los planes autónomos mantienen las confirmaciones para efectos sensibles.

Ejemplo de lectura para la carpeta de Nano que sí se observó en el teléfono (no se ejecutó durante esta auditoría):

```text
@mcp call nano-linux/nano.linux.fs.list {"path":"/data/user/0/dev.nanoai.mobile/files/nano/home"}
```

Un `cd` o un `export` en la terminal no cambia automáticamente la carpeta ni el entorno del conector MCP.

## Observación real del teléfono

Se autorizó y realizó solo lectura mediante ADB, sin navegar, ejecutar herramientas, enviar mensajes, inferir con modelos ni instalar.

- Dispositivo CPH2557; app `dev.nanoai.mobile` versión 1.0.0. La versión instalada corresponde a las 11:38:42 y precede estos cambios.
- Archivos presentes: Gemma E2B LiteRT de 2 588 147 712 bytes; Qwen 0.6B LiteRT de 347 251 840 bytes; EmbeddingGemma de 164 626 432 bytes. Su presencia y tamaño no prueban inferencia ni calidad.
- Existen ejecutor `nanortime` y utilidades bootstrap. No existe `files/nano/usr/bin`, por lo que no se encontraron Git ni Bash del rootfs completo en sus rutas previstas. No se instaló ni descargó ese entorno.
- En la ventana de hasta 600 registros recientes del PID de la app no aparecieron las palabras técnicas FATAL EXCEPTION, OutOfMemoryError o ANR. Tampoco eventos MCP/LiteRT/Nanoshell. Solo se conservaron conteos; esta ventana no demuestra ausencia de fallos.

## Validación y límites pendientes

- Gradle: `assembleFullSideloadDebug` terminó correctamente; APK final de 191 082 425 bytes.
- Dart: cero errores, una advertencia previa de símbolo no usado en `notification_draft_writer_capacity.part.dart` y 48 avisos de estilo. No se declara análisis global sin avisos.
- Los 88 archivos fuente del alcance revisado están bajo 200 líneas físicas (máximo 198). Se conservaron todos los alias del router original, incluidos los alternativos de Messenger. El inventario incluye archivos originales copiados/segmentados y algunos formateados; no es un diff Git.
- Se conservaron firmas públicas mediante composición de clases/mixins y partes por responsabilidad. Los comentarios explican contratos, límites y decisiones junto al código correspondiente.
- No se escribieron ni ejecutaron pruebas automatizadas. No se ejecutaron herramientas remotas ni operaciones del nuevo conector en el teléfono; la validación funcional en dispositivo queda pendiente.
- No se verificó visualmente la interfaz ejecutándose en el teléfono. La adaptación se revisó por sus restricciones de diseño en código.
- Comprensión VLM real desde MCP, RAG sobre la biblioteca PDF y runtimes especializados no se agregaron en esta intervención. Un adjunto identificado no equivale a adjunto comprendido.
- No se añadió OAuth ni un lanzador universal stdio/SSE/WebSocket. Las conexiones remotas integradas mantienen Streamable HTTP y token manual.
- Git del repositorio local sigue teniendo `HEAD` inválido; se preservaron respaldos originales de 24 archivos y un inventario por hashes. No se reseteó ni reparó Git.
- Se actualizó `.agents/skills/nano-mcp-terminal-integrity/SKILL.md` con estos invariantes para las próximas correcciones.

## Artefactos

`artifacts.json` conserva rutas, tamaños y SHA-256 de ambas copias del APK. `reviewed-source.json` contiene rutas, líneas y hashes de las fuentes revisadas. `alias-inspection.json` registra los alias conservados. `device-observation.json` y `device-log-counts.json` describen las lecturas autorizadas. Los logs de formato, análisis y compilación están en esta misma carpeta.

SHA-256 del APK final: `3bd89b65645f48dc1f45ef7992c1d1f719d877f9aed1b97c5b942d54c154a21a`.

El APK está compilado y **no instalado**. No se sustituyó la app del teléfono durante este trabajo.
