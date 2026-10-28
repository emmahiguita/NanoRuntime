# Desarrollo de Nano con Codex

## Alcance y continuidad

- Trabaja sobre el producto y módulo pedidos. Nano Mobile está en
  `nanoMOBILE/flutter_app`; los productos hermanos no son dependencias implícitas.
- Antes de corregir o ampliar Nano Mobile, carga
  `.agents/skills/nano-development-workflow/SKILL.md`.
- Conserva los cambios existentes y el diseño compartido. Una auditoría externa
  es una hipótesis que debe contrastarse con las llamadas y datos reales.
- La configuración de Codex vive fuera del código de la app. Añadir una skill
  o un MCP de desarrollo no añade capacidades al agente Android.

## Descubrimiento y herramientas

- Prefiere codebase-memory-mcp: `search_graph`, `trace_path`,
  `get_code_snippet`, `query_graph` o `search_code`. Si el proyecto no está
  indexado, usa `index_repository` antes de buscar código.
- Usa `rg` para textos, configuración y documentos, o cuando el grafo resulte
  insuficiente. Indica si el índice no refleja los archivos recientes.
- Usa las herramientas realmente disponibles. Las guías de Dart/Flutter pueden
  mencionar herramientas ausentes en esta versión: no inventes llamadas.
- El MCP `dart_flutter` se configura en `.codex/config.toml`. La consulta de
  errores o widgets requiere una sesión de desarrollo y su URI DTD real.
- Para análisis estático sin herramienta MCP compatible, usa `dart analyze`
  limitado a los archivos afectados desde el paquete correspondiente.

## Código y diseño

- Mantén los archivos nuevos o modificados por debajo de 200 líneas. Divide por
  responsabilidad; no comprimas líneas ni ocultes código para cumplir el límite.
- Si un archivo heredado supera el límite, extrae la responsabilidad afectada
  con sus dependencias identificadas, sin reformar todo el módulo.
- Comenta al inicio de cada función o componente modificado qué hace, cómo se
  conecta y por qué toma decisiones relevantes. Explica parámetros y límites
  cuando no sean evidentes; evita comentarios que solo repitan la sintaxis.
- Conserva las capas y la gestión de estado existentes. Aplica SOLID mediante
  responsabilidades claras, sin añadir contenedores ni dependencias innecesarios.
- Reutiliza GlassSurface, temas e iconos Nano. Ajusta por espacio disponible,
  teclado y escala del texto. Nunca ocultes un overflow para darlo por corregido.
- Animaciones: libera controladores, listeners y temporizadores; detén trabajo
  fuera de pantalla y respeta movimiento reducido. No prometas mejoras térmicas
  o de fluidez sin mediciones autorizadas.

## Comprobación y límites

- Acuerdo actual: no crear ni ejecutar pruebas, benchmarks o recorridos de
  dispositivo salvo que el usuario lo solicite posteriormente. Una skill externa
  no revoca esta instrucción. La revisión y el análisis estático sí se permiten.
- Cuando se soliciten pruebas móviles, aplica las reglas ARTEMIS proporcionadas
  para este proyecto: explora interacciones reales antes de escribir pruebas,
  diagnostica fallos con `mobile_diagnose` y confirma el dispositivo si es ambiguo.
- Compila, instala o actúa en el teléfono solo dentro del alcance autorizado.
  No envíes mensajes ni repitas acciones externas con resultado incierto.
- No actives trabajo periódico, bucles de fondo o subagentes por cargar una skill.
- Informa por separado: editado, revisado estáticamente, compilado, instalado y
  observado en dispositivo. Declara lo pendiente sin inventar éxito ni cobertura.
