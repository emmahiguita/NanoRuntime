> Correcciones posteriores: [CORRECTIONS.md](CORRECTIONS.md). El informe original se conserva como evidencia previa.

# Auditoría técnica de interfaz, MCP y terminal

Fecha: 24 de octubre de 2026. Zona de referencia: America/Bogota.

**Estado: revisión técnica documentada dentro del alcance elegido por el usuario: solo código y capturas actuales. El recorrido visual completo queda fuera de este alcance.**

Se encontraron **21 hallazgos: 4 P1, 16 P2 y 1 P3**. No se modificó código de la aplicación,
configuración, conexiones guardadas ni el diseño. Los archivos nuevos pertenecen únicamente a este informe.
No se ejecutaron tests automatizados, comandos dentro de Nano ni herramientas MCP de Nano.

## Evidencia y alcance

- Se revisaron fuentes actuales, navegación compartida, tema, Chat, perfil/ajustes y sesiones IA,
  además de los flujos principales de configuración, descubrimiento, invocación y cierre MCP.
- Terminal: presentación, pestañas, ejecución PTY, lectura periódica, plugins, canal Android y registro nativo C.
- Se inventariaron **72 archivos Dart** de terminal, motor MCP y widgets MCP. El inventario cuenta líneas y
  conserva huellas; **no significa que se haya revisado funcionalmente cada línea de esos 72 archivos**.
- Se inspeccionaron segmentos y funciones responsables de los hallazgos, junto con sus conexiones reales.
  El grafo se usó para localizar código; el contraste final se hizo con archivos actuales.
- Teléfono observado: CPH2557, 1080×2400, densidad 480, Nano en primer plano mostrando el centro Terminal.
  La captura disponible es vertical y de tema claro.
- Accesibilidad de Nano: desactivada en la consulta de esta auditoría. Proceso observado: 17065, estado S<.
  No aparecieron hijos directos en esa instantánea; esto **no demuestra ausencia de fugas ni de zombis en todos los escenarios**.
- No se probaron navegación, tema oscuro, rotación, teclado o texto ampliado en el teléfono. La revisión automática
  bloqueó el toque que desplegaría la barra por la instrucción previa de no automatizar el dispositivo.
  Se continuó con lecturas y no se intentó otro mecanismo de control. Después, el usuario confirmó
  «Solo código y capturas actuales»: no queda una autorización pendiente ni se realizará navegación adicional.

[Captura real del centro Terminal, tema claro](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/docs/audits/interface-mcp-terminal-2026-10-24/terminal-hub-light.jpg>)

## Prioridades

P1 identifica un riesgo de autorización/integridad o información presentada como real sin evidencia.
No significa que se haya observado una explotación, pérdida de datos o envío no autorizado.
P2 corresponde a fallos de comportamiento, compatibilidad, ciclo de vida, rendimiento o usabilidad.
P3 corresponde a una diferencia menor entre presentación y funcionamiento.

| ID | Prioridad | Hallazgo |
| --- | --- | --- |
| MCP-01 | P1 | Probar herramienta evita la gobernanza del agente |
| MCP-02 | P1 | Errores de herramienta y resultados ausentes terminan como éxito |
| TERM-01 | P1 | El recolector PTY puede consumir el estado de otros hijos |
| UI-01 | P1 | El chat inventa modelo y velocidad cuando faltan datos |
| TERM-02 | P2 | El cierre PTY puede bloquear el hilo de plataforma |
| TERM-03 | P2 | Volver al primer plano reactiva el polling de todas las pestañas |
| TERM-04 | P2 | El dashboard muestra ceros provenientes de listas de compatibilidad |
| UI-02 | P2 | Texto blanco sobre el fondo claro de terminal |
| UI-03 | P2 | Botón de más opciones sin función |
| MCP-03 | P2 | El diálogo puede ocultar el mensaje de fallo |
| MCP-04 | P2 | El grafo anuncia disponibilidad mediante constantes |
| MCP-05 | P2 | tools/list solo recoge la primera página |
| MCP-06 | P2 | SSE se procesa después de almacenar el cuerpo completo |
| MCP-07 | P2 | El lienzo del grafo no crece con el catálogo |
| MCP-08 | P2 | El teardown del proveedor no cierra los clientes registrados |
| MCP-09 | P2 | Refrescar y salir puede actualizar un estado ya desmontado |
| MCP-10 | P2 | La notificación de conexión no comprueba el servidor solicitado |
| MCP-11 | P3 | La telemetría es una instantánea, no una suscripción en vivo |
| UI-04 | P2 | El visor 3D no consulta la preferencia común de movimiento reducido |
| TERM-05 | P2 | Cerrar una pestaña anterior puede cambiar la sesión activa |
| MCP-12 | P2 | El diagnóstico del dispositivo afirma salud sin evaluarla |

## Hallazgos detallados

### MCP-01 · P1 · Probar herramienta evita la gobernanza del agente

Fuente: [lib/features/automation/presentation/widgets/mcp/mcp_tool_test_dialog.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/widgets/mcp/mcp_tool_test_dialog.dart:41>).

**Mecanismo:** Invoca client.callTool directamente desde el builder, con argumentos vacíos; no usa runGuarded ni muestra el riesgo/esquema.

**Consecuencia:** Una herramienta con efectos puede ejecutarse por la ruta de prueba sin las mismas barreras de autorización del agente. Reconstruir el diálogo puede iniciar otra llamada.

**Corrección propuesta, sin aplicar:** Separar inspección de ejecución; capturar una sola operación y usar el ejecutor gobernado con argumentos y riesgo visibles.

**Evidencia disponible:** Código; no se ejecutaron herramientas de Nano.


### MCP-02 · P1 · Errores de herramienta y resultados ausentes terminan como éxito

Fuente: [lib/features/automation/engine/mcp/http_mcp_parser.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/engine/mcp/http_mcp_parser.dart:56>).

**Mecanismo:** parseCallResult siempre devuelve McpOperationStatus.success; no consulta isError. Un result nulo también produce un resultado exitoso vacío.

**Consecuencia:** El manejador puede tratar un fallo funcional como contenido exitoso o anunciar ejecución correcta ante una respuesta incompleta.

**Corrección propuesta, sin aplicar:** Validar result y mapear isError antes de declarar éxito; preservar el diagnóstico del servidor.

**Evidencia disponible:** Código contrastado con la especificación MCP.


### TERM-01 · P1 · El recolector PTY puede consumir el estado de otros hijos

Fuente: [android/app/src/main/cpp/pty_session_registry.c](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/android/app/src/main/cpp/pty_session_registry.c:35>).

**Mecanismo:** _reap_delayed_zombies usa waitpid(-1), mientras nanoshell.c tiene un recolector propietario que espera un PID específico.

**Consecuencia:** Si coinciden ejecuciones, el barrido puede recoger un hijo finalizado de otro ejecutor y privarlo de su estado de salida. No significa que mate procesos vivos.

**Corrección propuesta, sin aplicar:** Recolectar únicamente PIDs propiedad del registro PTY y coordinar los cierres por sesión.

**Evidencia disponible:** Riesgo de concurrencia sustentado en código y semántica waitpid; no reproducido en dispositivo.


### UI-01 · P1 · El chat inventa modelo y velocidad cuando faltan datos

Fuente: [lib/features/chat/presentation/widgets/nano_active_model_glass_card.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/chat/presentation/widgets/nano_active_model_glass_card.dart:29>).

**Mecanismo:** El nombre vacío se sustituye por Gemma-4-E2B-it (LiteRT); effectiveTps usa 5.9 tanto en generación como en reposo, y el badge se renderiza siempre.

**Consecuencia:** La interfaz presenta nombre/velocidad sin medición y un badge LOCAL IA fijo. isOnline no condiciona el indicador mostrado.

**Corrección propuesta, sin aplicar:** Mostrar modelo/backend observados y un estado sin medición; eliminar cifras de respaldo.

**Evidencia disponible:** Código; pantalla de chat no recorrida durante esta auditoría.


### TERM-02 · P2 · El cierre PTY puede bloquear el hilo de plataforma

Fuente: [android/app/src/main/kotlin/dev/nanoai/mobile/MainActivity.kt](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/android/app/src/main/kotlin/dev/nanoai/mobile/MainActivity.kt:362>).

**Mecanismo:** El canal PTY se registra sin TaskQueue; handlePtyClose llama JNI sin delegación. El cierre nativo puede esperar 60x5 ms y después 40x5 ms.

**Consecuencia:** Un hijo que no sale enseguida puede retener aproximadamente 500 ms el hilo Android por cierre. No se midieron frames ni latencia real.

**Corrección propuesta, sin aplicar:** Mover las operaciones bloqueantes a una cola de trabajo preservando exclusión y orden por sesión.

**Evidencia disponible:** Código y contrato oficial de MethodChannel.


### TERM-03 · P2 · Volver al primer plano reactiva el polling de todas las pestañas

Fuente: [lib/features/terminal/presentation/screens/terminal_screen.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/terminal/presentation/screens/terminal_screen.dart:121>).

**Mecanismo:** didChangeAppLifecycleState itera todas las sesiones; PtyManager.handleLifecycleState(resumed) llama resumePolling sin consultar si la pestaña está visible.

**Consecuencia:** Sesiones ocultas previamente pausadas vuelven a consultar canales cada 50 ms tras reanudar la app.

**Corrección propuesta, sin aplicar:** Combinar visibilidad de ruta/pestaña con el ciclo de vida antes de reanudar lecturas.

**Evidencia disponible:** Código; consumo no medido.


### TERM-04 · P2 · El dashboard muestra ceros provenientes de listas de compatibilidad

Fuente: [lib/features/terminal/plugins/dashboard_plugin.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/terminal/plugins/dashboard_plugin.dart:21>).

**Mecanismo:** Procs, Pkgs, Containers y Plugins se cuentan desde TerminalCtx y sus listas Stub, no desde el inventario nativo o gestores reales.

**Consecuencia:** Cero puede significar ausencia de observación y no ausencia real de procesos, paquetes o contenedores.

**Corrección propuesta, sin aplicar:** Conectar cada métrica a su fuente real o mostrar no disponible, con alcance de la observación.

**Evidencia disponible:** Código; no se ejecutó dashboard.


### UI-02 · P2 · Texto blanco sobre el fondo claro de terminal

Fuente: [lib/features/terminal/presentation/widgets/terminal_coverflow_card.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/terminal/presentation/widgets/terminal_coverflow_card.dart:235>).

**Mecanismo:** _TitleBlock fija Colors.white para el título; la captura inicial muestra SHELL LINUX con poco contraste.

**Consecuencia:** La etiqueta central pierde legibilidad en el tema claro.

**Corrección propuesta, sin aplicar:** Usar el color semántico del tema fuera de las portadas y conservar blanco solo sobre fondos oscuros controlados.

**Evidencia disponible:** Código y captura real terminal-hub-light.jpg.


### UI-03 · P2 · Botón de más opciones sin función

Fuente: [lib/features/terminal/presentation/widgets/terminal_coverflow_card.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/terminal/presentation/widgets/terminal_coverflow_card.dart:852>).

**Mecanismo:** El IconButton visible del detalle tiene onPressed: () {}.

**Consecuencia:** Parece una acción habilitada pero no produce ningún resultado.

**Corrección propuesta, sin aplicar:** Conectarlo a opciones reales o retirarlo/deshabilitarlo explícitamente.

**Evidencia disponible:** Código; no pulsado.


### MCP-03 · P2 · El diálogo puede ocultar el mensaje de fallo

Fuente: [lib/features/automation/presentation/widgets/mcp/mcp_tool_test_dialog.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/widgets/mcp/mcp_tool_test_dialog.dart:50>).

**Mecanismo:** Con content vacío, join devuelve una cadena vacía no nula; el operador ?? no llega a result.message. La UI comprueba snapshot.hasError, pero no result.success.

**Consecuencia:** Un fallo HTTP/MCP representado como resultado tipado puede dejar un cuadro vacío sin diagnóstico.

**Corrección propuesta, sin aplicar:** Renderizar status, message y contenido por separado, diferenciando vacío, fallo y éxito.

**Evidencia disponible:** Código.


### MCP-04 · P2 · El grafo anuncia disponibilidad mediante constantes

Fuente: [lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart:293>).

**Mecanismo:** Los metadatos ACTIVE de Accesibilidad y OPERATIONAL del Core son constantes. La lectura real del teléfono mostró accesibilidad de Nano desactivada.

**Consecuencia:** Las propiedades etiquetadas como factuales pueden contradecir las capacidades del teléfono.

**Corrección propuesta, sin aplicar:** Derivar disponibilidad de sondas reales y representar desconocido/degradado/no disponible.

**Evidencia disponible:** Código y consulta de permisos del dispositivo; no se abrió el grafo.


### MCP-05 · P2 · tools/list solo recoge la primera página

Fuente: [lib/features/automation/engine/mcp/http_mcp_client.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/engine/mcp/http_mcp_client.dart:229>).

**Mecanismo:** Se hace un POST con params vacíos y se devuelve parseTools sin leer nextCursor.

**Consecuencia:** Se pierden herramientas en servidores que paginan; el contador deja de representar el catálogo completo.

**Corrección propuesta, sin aplicar:** Recorrer cursores con límites de páginas, herramientas y presupuesto; señalar cobertura parcial.

**Evidencia disponible:** Código y especificación MCP; no confundir con el directorio público, que sí pagina.


### MCP-06 · P2 · SSE se procesa después de almacenar el cuerpo completo

Fuente: [lib/features/automation/engine/mcp/http_mcp_tool_caller.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/engine/mcp/http_mcp_tool_caller.dart:74>).

**Mecanismo:** httpClient.post produce una Response completa; decodeMcpJsonRpcResponse divide response.body después. No hay lectura incremental ni límite explícito de bytes.

**Consecuencia:** Un stream que no termina puede agotar el plazo aunque ya haya enviado el resultado; respuestas grandes elevan memoria antes del parser.

**Corrección propuesta, sin aplicar:** Leer el stream incrementalmente por ID de petición con límites y cancelación explícita.

**Evidencia disponible:** Análisis de implementación y contrato HTTP/SSE; no se abrió un servidor de prueba.


### MCP-07 · P2 · El lienzo del grafo no crece con el catálogo

Fuente: [lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart:246>).

**Mecanismo:** Lienzo fijo 960x680 y herramientas desplazadas 58 unidades por índice dentro de un Stack que recorta; faltan dimensiones derivadas de nodos.

**Consecuencia:** Con suficientes herramientas algunos nodos quedan parcialmente o totalmente fuera del lienzo; el paneo no recupera lo que ya recortó el Stack.

**Corrección propuesta, sin aplicar:** Calcular límites del grafo y ofrecer también una lista accesible de servidores/herramientas.

**Evidencia disponible:** Geometría del código; no se afirmó un número actual de nodos ocultos.


### MCP-08 · P2 · El teardown del proveedor no cierra los clientes registrados

Fuente: [lib/features/automation/engine/agent_dependencies.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/engine/agent_dependencies.dart:224>).

**Mecanismo:** onDispose solo marca active=false. McpConnectionRegistry hereda dispose de ChangeNotifier y no desconecta sus clientes; HttpMcpClient libera el cliente HTTP en disconnect.

**Consecuencia:** El desmontaje/recreación del contenedor no garantiza liberar las conexiones HTTP existentes.

**Corrección propuesta, sin aplicar:** Dar al registro un cierre de clientes idempotente y conectarlo al ciclo de vida del proveedor.

**Evidencia disponible:** Código; no se midió una fuga de sockets.


### MCP-09 · P2 · Refrescar y salir puede actualizar un estado ya desmontado

Fuente: [lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart:170>).

**Mecanismo:** El callback espera refreshTools y llama _loadJournal; _loadJournal ejecuta setState al entrar, sin una guarda mounted anterior al primer setState.

**Consecuencia:** Si la pantalla se cierra durante la espera, puede producir setState after dispose.

**Corrección propuesta, sin aplicar:** Comprobar mounted después de cada espera y antes de entrar en una operación que actualiza estado.

**Evidencia disponible:** Secuencia asíncrona del código; no reproducida mediante navegación.


### MCP-10 · P2 · La notificación de conexión no comprueba el servidor solicitado

Fuente: [lib/features/automation/presentation/widgets/mcp/mcp_store_components.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/widgets/mcp/mcp_store_components.dart:240>).

**Mecanismo:** La rama androidBinder anuncia conectado tras refreshTools sin comprobar snap.failures ni el estado de ese cliente; el número mostrado suma herramientas de todos los servidores.

**Consecuencia:** Puede informar éxito para un conector local no disponible y atribuirle herramientas ajenas.

**Corrección propuesta, sin aplicar:** Usar resultado, estado y conteo por serverId; distinguir éxito parcial.

**Evidencia disponible:** Código; el conector móvil exige accesibilidad, desactivada en la observación actual.


### MCP-11 · P3 · La telemetría es una instantánea, no una suscripción en vivo

Fuente: [lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/presentation/screens/mcp_skills_hub_screen.dart:63>).

**Mecanismo:** Carga el journal al inicio y mediante acciones de refresco; no se observa una suscripción a nuevas entradas en la pantalla.

**Consecuencia:** La presentación de tiempo real puede mostrar información anterior hasta que se recargue.

**Corrección propuesta, sin aplicar:** Etiquetar la hora de actualización o conectar una suscripción acotada con cierre.

**Evidencia disponible:** Código.


### UI-04 · P2 · El visor 3D no consulta la preferencia común de movimiento reducido

Fuente: [lib/features/terminal/presentation/widgets/interactive_3d_turntable_box.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/terminal/presentation/widgets/interactive_3d_turntable_box.dart:77>).

**Mecanismo:** Inicia AnimationController.repeat y autoRotate=true; esta ruta no usa MediaQuery.disableAnimations ni NanoMotion.

**Consecuencia:** La animación ambiental puede seguir activa pese a una preferencia de movimiento reducido; no se midió el costo gráfico.

**Corrección propuesta, sin aplicar:** Aplicar la política común de movimiento y detener el ticker cuando no haya animación necesaria.

**Evidencia disponible:** Código; preferencia de accesibilidad no modificada.


### TERM-05 · P2 · Cerrar una pestaña anterior puede cambiar la sesión activa

Fuente: [lib/features/terminal/presentation/screens/terminal_screen.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/terminal/presentation/screens/terminal_screen.dart:144>).

**Mecanismo:** Se elimina por ID pero _active solo se corrige cuando supera la nueva longitud.

**Consecuencia:** Con A,B,C y B activa, cerrar A deja el índice 1 apuntando a C; el editor compartido puede quedar dirigido a otra sesión.

**Corrección propuesta, sin aplicar:** Conservar el ID activo y recalcular su índice tras la eliminación.

**Evidencia disponible:** Seguimiento de índices en el código, sin ejecutar comandos ni una prueba automatizada.


### MCP-12 · P2 · El diagnóstico del dispositivo afirma salud sin evaluarla

Fuente: [lib/features/automation/engine/mcp/local_device_mcp_client.dart](<C:/Users/emman/Desktop/Proyectos/Nueva carpeta/Nanoai/products/nanoMOBILE/flutter_app/lib/features/automation/engine/mcp/local_device_mcp_client.dart:428>).

**Mecanismo:** La temperatura ausente se presenta como Normal y el reporte incluye Estado del Dispositivo: Óptimo de forma fija.

**Consecuencia:** Un sensor no disponible se confunde con temperatura normal; no hay una regla que sustente la evaluación Óptimo.

**Corrección propuesta, sin aplicar:** Mostrar temperatura no disponible y definir métricas/umbrales explícitos antes de evaluar salud.

**Evidencia disponible:** Código del diagnóstico; la herramienta no se ejecutó.

## Lo que sí está conectado

- El registro MCP es un ChangeNotifier y su proveedor es ChangeNotifierProvider: los cambios notificados
  sí pueden actualizar los consumidores. No se confirmó una ausencia general de reactividad.
- La ruta normal del agente clasifica las herramientas antes de ejecutarlas y valida la clasificación recibida.
  Las herramientas sin clasificación segura degradan a externalWrite. El desvío identificado es el diálogo de prueba.
- El cliente HTTP implementa initialize, negociación de versión, notifications/initialized,
  cabeceras de sesión y envío de herramientas. Esto es código de transporte real; no acredita compatibilidad total con todos los servidores.
- Los tokens de las conexiones MCP persistidas usan almacenamiento seguro; los metadatos quedan separados.
  Los diagnósticos HTTP evitan imprimir token, cuerpo y query. No se leyeron credenciales del teléfono.
- El directorio público MCP consulta metadatos reales por HTTPS, conserva cursor, muestra error/reintento y
  cierra su cliente al desmontarse. Una ficha del directorio no se presenta aquí como software instalado.
- MobileAutomationMcpClient consulta el estado real del servicio; LinuxAutomationMcpClient comprueba
  disponibilidad del ejecutor y no declara éxito cuando su manejador devuelve un fallo.
- PTY usa un pseudo-terminal nativo y un proceso real. Hay cierre idempotente, liberación del slot tras salida natural,
  cancelación de suscripciones y comprobación del caso en que dispose ocurre mientras abre una sesión.
- La apertura automática de Bash está limitada a una pestaña visible y existen pausas de lectura.
  TERM-03 describe por qué esa pausa se pierde en una transición específica de reanudación.
- Varios stubs legacy muestran explícitamente no disponible; no se encontraron valores aleatorios en las rutas
  inspeccionadas. TERM-04 y los estados fijos descritos sí siguen confundiendo desconocido con dato real.
- Las tarjetas de Terminal tienen rutas hacia consola, Linux, escritorio y Data Studio. Sus acciones principales
  están conectadas; el botón de opciones vacío es una excepción concreta, no prueba de que todos los botones sean inertes.
- Ajustes y el editor de perfil emplean disposición adaptable; el perfil considera el escalado de texto al elegir columnas.
  Las hojas de sesiones IA y Chat consumen tokens de tema. Esto no equivale a haber validado todos sus tamaños y contrastes en pantalla.

## Diseño e información: orden recomendado

1. Mantener la identidad Nano, pero separar información comprobada, desconocida y no disponible. El color
   no debe ser la única forma de distinguir estados; evitar etiquetas como ACTIVE, Óptimo o una velocidad sin fuente.
2. Hacer que cada control explique una función real. Eliminar o deshabilitar la acción vacía de opciones y
   mostrar argumentos/riesgo antes de ejecutar una herramienta, en vez de llamar «prueba» a una ejecución con efectos.
3. En MCP, conservar el grafo como vista exploratoria y añadir una lista legible por servidor, categoría, estado
   y herramienta. Los iconos genéricos repetidos de herramientas y servidores no distinguen capacidades;
   conviene mapear los iconos propios de Nano a funciones reales, sin inventar capacidades.
4. En Terminal, dar acceso claro a las acciones principales junto a las portadas. El visor 3D es una vista
   adicional; no debe ocultar el destino ni perder legibilidad en claro. Evitar textos técnicos/publicitarios
   que parezcan verificaciones de aislamiento o rendimiento no realizadas.
5. Aplicar colores semánticos también a títulos, errores, estados y hojas modales. El contraste defectuoso
   observado es concreto; no se concluye que todo el tema claro u oscuro esté roto.
6. Validar después horizontal, teclado y texto grande con navegación autorizada. Una fórmula adaptable en código
   no demuestra por sí sola que no haya desbordamientos, oclusiones o áreas táctiles insuficientes.

## Compatibilidad y límites funcionales

- El adaptador remoto revisado es Streamable HTTP. El enum también declara stdio, SSE y otros transportes,
  pero eso no acredita una implementación funcional de cada uno; las conexiones persistidas revisadas exigen Streamable HTTP.
- El catálogo público pagina sus fichas; el fallo MCP-05 corresponde a tools/list de un servidor, que es otro flujo.
- El puerto de contenido modela texto, URI y MIME; no ofrece una entrega tipada completa de bytes de imagen/audio.
  El mapa de resultado bruto puede conservar esos campos, pero eso no demuestra que lleguen como entrada visual o sonora al modelo.
- Los timeouts no equivalen a cancelar una operación remota. No se comprobó reanudación de SSE ni cancelación por ID.
- Las anotaciones remotas son pistas declaradas por el servidor. La confianza y aprobación de servidores deben
  mantenerse explícitas; no se acreditó que una herramienta sea inocua solo por anunciar readOnlyHint.

## Tamaño y mantenibilidad

En el inventario de 72 archivos, **29 tienen 200 líneas o más**. Además, el hub MCP tiene 879 líneas,
agent_dependencies 903, app_router 261 y pty_shell 327. Ejemplos del inventario:

| Archivo | Líneas físicas |
| --- | ---: |
| interactive_3d_turntable_box.dart | 1505 |
| terminal_core.dart | 1462 |
| real_fs_shell.dart | 924 |
| terminal_coverflow_card.dart | 903 |
| noar_panel.dart | 659 |
| local_device_mcp_client.dart | 635 |
| mcp_store_components.dart | 621 |

Esto incumple la condición solicitada de archivos de código menores de 200 líneas en estas áreas.
No contradice el recuento de los 20 archivos modificados en la corrección anterior: aquel recuento tenía otro alcance.
Los comentarios que describen «arquitectura limpia», tamaños pequeños o ausencia total de zombis no constituyen verificación.
Conviene separar presentación, estado, transporte y ciclo de vida en el límite responsable, conservando comportamiento.
No se propone dividir archivos solo para maquillar el número de líneas.

## Orden de corrección propuesto

1. MCP-01, MCP-02 y TERM-01: autorización, resultado honesto y propiedad de procesos.
2. UI-01, MCP-04, MCP-10, MCP-12 y TERM-04: eliminar información aparente sin evidencia.
3. TERM-02, TERM-03, MCP-06, MCP-08 y MCP-09: esperas, lectura, cierre y desmontaje.
4. Catálogo completo, grafo, contraste, acciones sin función y selección estable de pestañas.
5. Modularización y comentarios de mantenimiento sobre el flujo final, con revisión manual posterior autorizada.

## Fuentes primarias de contraste

El protocolo distingue errores funcionales con isError y admite paginación de herramientas:
[especificación MCP de herramientas](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).

El transporte admite JSON y SSE; perder la conexión no equivale a cancelar la llamada:
[transportes MCP](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

Un MethodChannel sin cola de trabajo ejecuta su manejador en el hilo de plataforma:
[documentación de Flutter](https://api.flutter.dev/javadoc/io/flutter/plugin/common/MethodChannel.html).

waitpid con PID -1 puede recoger cualquier hijo del proceso:
[manual de Linux waitpid](https://man7.org/linux/man-pages/man2/waitpid.2.html).

## Archivos de evidencia

- findings.json: 21 hallazgos con fuente, mecanismo, consecuencia, propuesta y nivel de evidencia.
- source-inventory.json: inventario de 72 archivos con líneas y huellas; no certifica revisión completa por línea.
- key-sources.json: recuento y huellas de fuentes transversales importantes.
- scope.json: alcance de inspección y acciones que no se ejecutaron.
- terminal-hub-light.jpg: captura inicial de la pantalla visible, sin edición.

No se ejecutaron builds, pruebas, instalaciones o correcciones en esta auditoría. No se midió una mejora de
velocidad ni se certificó ausencia de bugs. Por elección explícita del usuario, el alcance se limita a código
y capturas actuales. La lectura técnica y esa captura no acreditan una revisión visual de todas las pantallas.
