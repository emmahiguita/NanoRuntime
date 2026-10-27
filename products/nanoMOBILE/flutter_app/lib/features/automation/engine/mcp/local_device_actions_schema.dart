part of 'local_device_mcp_client.dart';

/// Esquemas MCP de actions; describen argumentos y no ejecutan operaciones.
const _actionsTools = <McpRemoteTool>[
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_type_text',
    description:
        'Escribe texto en un editable reidentificado y enfocado de forma segura.',
    inputSchema: {
      'type': 'object',
      'required': ['selector', 'text'],
      'properties': {
        'selector': {'type': 'string'},
        'text': {'type': 'string'},
      },
    },
    annotations: McpToolAnnotations(
      readOnlyHint: false,
      idempotentHint: false,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_back',
    description: 'Ejecuta la accion global Android Back.',
    inputSchema: {'type': 'object', 'properties': {}},
    annotations: McpToolAnnotations(
      readOnlyHint: false,
      idempotentHint: false,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_home',
    description: 'Ejecuta la accion global Android Home.',
    inputSchema: {'type': 'object', 'properties': {}},
    annotations: McpToolAnnotations(
      readOnlyHint: false,
      idempotentHint: false,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'mobile_open_app',
    description: 'Abre una aplicacion Android por packageName explicito.',
    inputSchema: {
      'type': 'object',
      'required': ['packageName'],
      'properties': {
        'packageName': {'type': 'string'},
      },
    },
    annotations: McpToolAnnotations(
      readOnlyHint: false,
      idempotentHint: false,
      destructiveHint: false,
      openWorldHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'diagnostics',
    description:
        'Consulta el estado de salud físico, batería y memoria del dispositivo.',
    inputSchema: {'type': 'object', 'properties': {}},
    annotations: McpToolAnnotations(
      readOnlyHint: true,
      idempotentHint: true,
      destructiveHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'app_summary',
    description:
        'Consulta el recuento y resumen del catálogo de aplicaciones instaladas.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'filter': {
          'type': 'string',
          'description': 'Filtro opcional por nombre o paquete',
        },
      },
    },
    annotations: McpToolAnnotations(
      readOnlyHint: true,
      idempotentHint: true,
      destructiveHint: false,
    ),
  ),
  McpRemoteTool(
    serverId: 'device',
    name: 'system_features',
    description:
        'Consulta capacidades de hardware y subsistemas del dispositivo.',
    inputSchema: {'type': 'object', 'properties': {}},
    annotations: McpToolAnnotations(
      readOnlyHint: true,
      idempotentHint: true,
      destructiveHint: false,
    ),
  ),
];
