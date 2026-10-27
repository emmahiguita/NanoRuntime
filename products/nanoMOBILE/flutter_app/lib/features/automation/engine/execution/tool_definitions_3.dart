part of 'tool_registry.dart';

/// Herramientas registradas: conserva sintaxis, timeout y compatibilidad.
const _toolDefinitions3 = <ToolDefinition>[
  ToolDefinition(
    name: 'scroll',
    timeout: Duration(seconds: 5),
    description: 'Desplazar la pantalla en una dirección',
  ),
  ToolDefinition(
    name: 'long_press',
    timeout: Duration(seconds: 5),
    description: 'Mantener pulsado un punto de la pantalla',
  ),
  ToolDefinition(
    name: 'open_system',
    timeout: Duration(seconds: 5),
    description: 'Abrir un destino de sistema allowlisted',
  ),
  ToolDefinition(
    name: 'device.set_alarm',
    timeout: Duration(seconds: 15),
    description: 'Programar una alarma o despertador en el reloj del sistema',
    promptSyntax:
        '{"tool":"device.set_alarm","hour":8,"minutes":0,"message":"Despertador","weekdays":[1,2,3,4,5]}',
  ),
  ToolDefinition(
    name: 'dev.inspect_app',
    timeout: Duration(seconds: 10),
    description: 'Inspeccionar metadatos y superficie accesible de una app',
    promptSyntax: '{"tool":"dev.inspect_app","target":"<paquete_o_nombre>"}',
  ),
  ToolDefinition(
    name: 'dev.diagnostics',
    timeout: Duration(seconds: 10),
    description: 'Diagnóstico factual de capacidades de hardware y sistema',
    promptSyntax: '{"tool":"dev.diagnostics"}',
  ),
  ToolDefinition(
    name: 'dev.adb',
    timeout: Duration(seconds: 20),
    description: 'Comandos y emparejamiento con ADB inalámbrico local',
    promptSyntax: '{"tool":"dev.adb","command":"pair|connect|devices|shell"}',
  ),
  ToolDefinition(
    name: 'open_url',
    timeout: Duration(seconds: 10),
    description: 'Abrir una URL http/https en el navegador',
  ),
  ToolDefinition(
    name: 'fetch_web',
    timeout: Duration(seconds: 15),
    description:
        'Consultar contenido o texto de una página web o API en internet',
    promptSyntax: '{"tool":"fetch_web","url":"<url>"}',
  ),
  ToolDefinition(
    name: 'search_knowledge',
    timeout: Duration(seconds: 15),
    description:
        'Buscar y sintetizar conocimiento de internet directamente dentro de Nano',
    promptSyntax: '{"tool":"search_knowledge","query":"<consulta>"}',
  ),
];
