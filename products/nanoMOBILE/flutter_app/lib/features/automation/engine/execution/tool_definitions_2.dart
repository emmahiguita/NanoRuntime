part of 'tool_registry.dart';

/// Herramientas registradas: conserva sintaxis, timeout y compatibilidad.
const _toolDefinitions2 = <ToolDefinition>[
  ToolDefinition(
    name: 'messenger.share_file',
    timeout: Duration(seconds: 25),
    description: 'Compartir un archivo por Facebook Messenger',
    promptSyntax:
        '{"tool":"messenger.share_file","contact":"<contacto_o_usuario>","path":"<ruta_archivo>","caption":"<texto_opcional>"}',
  ),
  ToolDefinition(
    name: 'linux.list',
    timeout: Duration(seconds: 15),
    description: 'Listar archivos en el subsistema Linux',
    promptSyntax: '{"tool":"linux.list","path":"<ruta_absoluta>"}',
  ),
  ToolDefinition(
    name: 'linux.readFile',
    timeout: Duration(seconds: 15),
    description: 'Leer un archivo del subsistema Linux',
    promptSyntax: '{"tool":"linux.readFile","path":"<ruta_absoluta>"}',
  ),
  ToolDefinition(
    name: 'linux.writeFile',
    timeout: Duration(seconds: 20),
    description: 'Escribir un archivo en el subsistema Linux',
    promptSyntax:
        '{"tool":"linux.writeFile","path":"<ruta_absoluta>","content":"<texto>"}',
  ),
  ToolDefinition(
    name: 'linux.run',
    timeout: Duration(seconds: 30),
    description: 'Ejecutar un comando en el subsistema Linux',
    promptSyntax:
        '{"tool":"linux.run","command":"<cmd>","args":["<arg1>","<arg2>"]}',
  ),
  ToolDefinition(
    name: 'home',
    timeout: Duration(seconds: 5),
    description: 'Ir a la pantalla de inicio',
  ),
  ToolDefinition(
    name: 'recents',
    timeout: Duration(seconds: 5),
    description: 'Abrir la vista de aplicaciones recientes',
  ),
  ToolDefinition(
    name: 'open_notifications',
    timeout: Duration(seconds: 5),
    description: 'Abrir la sombra de notificaciones',
  ),
  ToolDefinition(
    name: 'open_quick_settings',
    timeout: Duration(seconds: 5),
    description: 'Abrir los ajustes rápidos',
  ),
  ToolDefinition(
    name: 'swipe',
    timeout: Duration(seconds: 5),
    description: 'Deslizar entre dos puntos de la pantalla',
  ),
];
