part of 'tool_registry.dart';

/// Herramientas registradas: conserva sintaxis, timeout y compatibilidad.
const _toolDefinitions0 = <ToolDefinition>[
  ToolDefinition(
    name: 'screen',
    description: 'Leer la pantalla actual del dispositivo',
    promptSyntax: '{"tool":"screen"}',
  ),
  ToolDefinition(
    name: 'read_screen',
    description: 'Leer el texto legible de la pantalla o página web',
    promptSyntax: '{"tool":"read_screen"}',
  ),
  ToolDefinition(
    name: 'resolve',
    description: 'Resolver un selector contra el árbol de accesibilidad',
    promptSyntax: '{"tool":"resolve","selector":"<selector>"}',
  ),
  ToolDefinition(
    name: 'tap',
    // Un tap genérico puede ser navegación o el botón de envío. Al no poder
    // distinguirlo sin observar el contexto, se protege de forma conservadora.
    description: 'Tocar un elemento de la pantalla',
    promptSyntax: '{"tool":"tap","selector":"<selector>"}',
  ),
  ToolDefinition(
    name: 'back',
    timeout: Duration(seconds: 5),
    description: 'Presionar el botón atrás',
    promptSyntax: '{"tool":"back"}',
  ),
  ToolDefinition(
    name: 'launch_app',
    timeout: Duration(seconds: 10),
    description: 'Abrir una aplicación instalada por su paquete Android',
  ),
  ToolDefinition(
    name: 'write',
    description: 'Escribir texto en un campo de una aplicación',
    promptSyntax: '{"tool":"write","selector":"<selector>","text":"<texto>"}',
  ),
  ToolDefinition(
    name: 'notifications',
    description: 'Leer las notificaciones activas del dispositivo',
    promptSyntax: '{"tool":"notifications"}',
  ),
  ToolDefinition(
    name: 'device_state',
    timeout: Duration(seconds: 5),
    description:
        'Consultar estado del dispositivo (batería, carga, memoria, conectividad)',
    promptSyntax: '{"tool":"device_state"}',
  ),
  ToolDefinition(
    name: 'reply_notification',
    description: 'Responder una notificación en una aplicación externa',
    promptSyntax:
        '{"tool":"reply_notification","key":"<key>","text":"<texto>"}',
  ),
];
