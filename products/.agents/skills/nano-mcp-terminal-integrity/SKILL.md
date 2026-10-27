---
name: nano-mcp-terminal-integrity
description: Mantener la inspección y transporte MCP de Nano Mobile, los estados observados del grafo y el ciclo de vida propietario de sus terminales PTY.
---

# Integridad de MCP y terminal en Nano

Usa esta guía al corregir el hub MCP, sus clientes HTTP o el cierre/visibilidad PTY. No concede autorización para ejecutar herramientas, comandos o navegar por un teléfono.

## Invariantes de MCP

- La inspección del grafo muestra servidor, herramienta y esquema. No invoca `callTool` desde un `builder` ni elige otro servidor si falta el solicitado.
- Conserva la ejecución del agente a través de gobernanza y confirmaciones existentes. Las anotaciones remotas describen intención; no conceden permisos.
- `HttpMcpParser` diferencia `isError`, resultado ausente y éxito. Conserva el texto de fallo remoto para consumidores de `message`.
- `mcp_bounded_http.dart` lee JSON/SSE por ID JSON-RPC, limita bytes y tiempo y cancela su propia lectura. Cerrar el transporte no demuestra cancelación remota de la herramienta.
- El catálogo recorre `nextCursor`, rechaza ciclos y no publica cobertura parcial como completa. Los límites actuales son 20 páginas, 1000 herramientas y 30 segundos de lectura; revisa el presupuesto del registro si cambian.
- El registro es dueño del cierre de todos sus clientes. Resultados tardíos no notifican después de `dispose`.
- La conexión y el conteo se evalúan por `serverId`. Los permisos y la salud no se deducen de la existencia de un nodo; usa desconocido si falta evidencia.
- El journal mostrado es una instantánea con fecha. No lo anuncies como una suscripción continua.

## Invariantes de PTY

- El registro C solo recolecta PIDs propios. Nunca uses `waitpid(-1)` en él: puede consumir la salida de hijos de nanoshell.
- Reserva el slot durante el cierre y conserva el PID si la espera acotada termina antes que el hijo. `EINTR` no demuestra salida; `ECHILD` significa que ya no pertenece al recolector.
- JNI bloqueante se despacha por la cola Kotlin acotada, en orden y sin retener Activity. El trabajador debe expirar al quedar inactivo.
- El polling exige aplicación reanudada, ruta visible y pestaña seleccionada. Reanudar la aplicación no reanuda todas las pestañas ocultas.
- Al cerrar una pestaña conserva el ID activo antes de recalcular el índice. No dirijas el editor a otra sesión por un desplazamiento de índices.

## Presentación y comprobación

Conserva nombres públicos, rutas, claves de sesiones y diseño existente. Los colores fuera de portadas deben salir del tema. El movimiento ambiental del visor respeta `MediaQuery.disableAnimations`; una acción sin implementación se retira en lugar de simular éxito.

Separa archivos por responsabilidad y mantén el límite de líneas pedido por el usuario. Comenta junto a cada componente qué hace y las razones de sus límites.

Respeta el alcance de comprobación autorizado. Si solo se autoriza código, formato/análisis/compilación no prueban comportamiento visual ni entrega real. Registra lo observado y lo pendiente sin declarar ausencia total de bugs. No añadas tests si el usuario los excluye.

Referencia de la corrección: `nanoMOBILE/flutter_app/docs/audits/interface-mcp-terminal-2026-10-24/CORRECTIONS.md`, desde la raíz products.

## Integración del agente con Linux

- Las categorías `mcp.read/device/externalWrite/privileged` tienen contratos en `semantic_mcp_policies.dart`. La ausencia de contrato no equivale a observación. Los modos de autonomía no rebajan su consentimiento canónico.
- Solo `McpLocalToolPolicy` clasifica herramientas internas de identidades reservadas. Un `readOnlyHint` remoto no concede lectura sin confirmación.
- Valida `inputSchema` y argumentos antes de `callTool`. `McpSchemaValidator` usa un isolate con plazo, sin resolución de referencias de red. JSON truncado no se reconstruye ni ejecuta parcialmente; el parser conserva mayúsculas canónicas, escapes y contenido literal.
- Conserva `ToolExecutionReport` desde el manejador hasta el dispatcher y journal. No deduzcas fallo por un prefijo del texto MCP. Un resultado remoto satisfactorio no prueba un efecto externo verificado; binarios sin adaptador se identifican sin fingir comprensión visual.
- `nano-linux` es un conector en proceso, independiente de PTY. Su catálogo publica operaciones concretas con rutas explícitas; no agregues shell libre o extracción de archivos como si fueran operaciones auditadas. El bootstrap básico no demuestra rootfs completo ni Git instalado.
- La escritura literal usa `printf` con comillas y verificación SHA-256. No recortes espacios ni añadas el salto de línea de un heredoc.
- El supervisor distingue solicitud, salida observada, parada pendiente y finalización. `killTracked` solo prueba envío de señal; confirma salida con su futuro. No inventes PID y no anuncies tareas terminadas como activas.
- La preparación visual valida y copia un comando. No ejecuta acciones. Enviar un comando humano al agente autoriza esa llamada concreta; las propuestas autónomas conservan confirmación.

Referencia: `nanoMOBILE/flutter_app/docs/audits/mcp-terminal-implementation-2026-10-24/IMPLEMENTATION.md`.

## Legibilidad y propiedad de la terminal

- Los 16 colores ANSI base son RGB: al construir `Color`, añade alpha `0xff` o el texto de programas queda transparente. Conserva la paleta de 256 colores y el protocolo.
- La salida ANSI y el cálculo de filas/columnas PTY usan el mismo `terminalTextStyle`; cambiar fuente o tamaño en un solo lado desalineará aplicaciones interactivas.
- El editor de Terminal pertenece a su pantalla y comparte controlador/foco con la sesión activa. No agregues otro editor universal para el mismo comando. Conserva Enter, botón y comandos guardados en el mismo ejecutor.
- Un manejador HardwareKeyboard no recibe teclas si la pestaña no es visible o su editor no tiene foco. El cursor cancela su temporizador al ocultarse la pestaña, salir a segundo plano o solicitar movimiento reducido.
- Conserva los comandos guardados; retira el flotante superpuesto y su temporizador cuando la acción pase al menú. No borres una biblioteca del usuario para quitar un control duplicado.
- `TermuxDistribution` debe comprobar el resultado de instalación y el shell real; no cachear `true` incondicionalmente. `HOME` pertenece a Nano, nunca a `com.termux`.
- Una instalación debug puede descargar otro release. El marker registra etiqueta y SHA-256 realmente verificados, sin sustituirlos por el pin release del código.

Referencia de continuación: `nanoMOBILE/flutter_app/docs/audits/mcp-terminal-implementation-2026-10-24/TERMINAL-COMPLETION.md`.
