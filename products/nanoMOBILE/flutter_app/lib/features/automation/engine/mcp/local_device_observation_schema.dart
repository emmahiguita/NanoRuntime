part of 'local_device_mcp_client.dart';

/// Esquemas MCP de observation; describen argumentos y no ejecutan operaciones.
const _observationTools = <McpRemoteTool>[
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_get_device_state',
    description:
        'Obtiene el package, activity, servicio de accesibilidad y resumen semantico de la pantalla actual.',
    inputSchema: {'type': 'object', 'properties': {}},
    annotations: McpToolAnnotations(
      readOnlyHint: true,
      idempotentHint: true,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_observe',
    description:
        'Captura un snapshot sincronizado de jerarquia Android y, opcionalmente, screenshot PNG.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'includeScreenshot': {
          'type': 'boolean',
          'default': false,
          'description': 'Incluye el PNG codificado en base64.',
        },
        'maxNodes': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 500,
          'default': 120,
        },
      },
    },
    annotations: McpToolAnnotations(
      readOnlyHint: true,
      idempotentHint: true,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_find_element',
    description:
        'Resuelve un selector semantico dinamico contra un snapshot fresco sin ejecutar acciones.',
    inputSchema: {
      'type': 'object',
      'required': ['selector'],
      'properties': {
        'selector': {
          'type': 'string',
          'description':
              'Nano selector: text=Buscar, id=..., role=button;text=Enviar.',
        },
      },
    },
    annotations: McpToolAnnotations(
      readOnlyHint: true,
      idempotentHint: true,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_tap_element',
    description:
        'Toca un elemento reidentificado por selector semantico; no acepta coordenadas libres.',
    inputSchema: {
      'type': 'object',
      'required': ['selector'],
      'properties': {
        'selector': {'type': 'string'},
      },
    },
    annotations: McpToolAnnotations(
      readOnlyHint: false,
      idempotentHint: false,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
];
