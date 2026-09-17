/// Catálogo formal de herramientas MCP de automatización móvil — Nano Mobile Engine
///
/// Principio de Responsabilidad Única (SRP):
/// Define exclusivamente los contratos, esquemas y metadatos de las herramientas.
library;

import 'mcp_client_port.dart';

abstract final class MobileAutomationToolCatalog {
  static const String serverId = 'nano.mobile';

  static List<McpRemoteTool> createToolDefinitions() {
    return const [
      McpRemoteTool(
        serverId: serverId,
        name: 'observe',
        description:
            'Obtiene una observación atómica y sincronizada del estado móvil (jerarquía y metadatos).',
        inputSchema: {
          'type': 'object',
          'properties': {
            'includeScreenshot': {
              'type': 'boolean',
              'description': 'Captura el PNG del fotograma correspondiente.',
              'default': false,
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
        serverId: serverId,
        name: 'tap',
        description:
            'Pulsa un elemento UI usando resolución dinámica prioritaria (Resource-ID -> Semántica -> Coordenadas).',
        inputSchema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Texto accesible del elemento.',
            },
            'resourceId': {
              'type': 'string',
              'description': 'Identificador de recurso (viewIdResourceName).',
            },
            'packageName': {
              'type': 'string',
              'description': 'Paquete esperado.',
            },
            'x': {
              'type': 'integer',
              'description': 'Coordenada X de fallback.',
            },
            'y': {
              'type': 'integer',
              'description': 'Coordenada Y de fallback.',
            },
            'mustAppearText': {
              'type': 'string',
              'description': 'Texto que debe aparecer para verificar el tap.',
            },
            'mustDisappearText': {
              'type': 'string',
              'description':
                  'Texto que debe desaparecer para verificar el tap.',
            },
            'expectedPackageAfter': {
              'type': 'string',
              'description': 'Package esperado despues del tap.',
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'type',
        description:
            'Escribe texto en un campo de entrada verificado o actualmente enfocado.',
        inputSchema: {
          'type': 'object',
          'required': ['text'],
          'properties': {
            'text': {'type': 'string', 'description': 'Texto a introducir.'},
            'targetResourceId': {
              'type': 'string',
              'description': 'Resource ID opcional para validación de foco.',
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'swipe',
        description:
            'Ejecuta un desplazamiento direccional en pantalla o entre coordenadas.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'direction': {
              'type': 'string',
              'enum': ['up', 'down', 'left', 'right'],
            },
            'durationMs': {'type': 'integer', 'default': 300},
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'press_key',
        description:
            'Dispara una acción global del sistema Android (back, home, recents, enter).',
        inputSchema: {
          'type': 'object',
          'required': ['key'],
          'properties': {
            'key': {
              'type': 'string',
              'enum': ['back', 'home', 'recents', 'enter'],
              'description': 'Tecla o acción global a despachar.',
            },
            'expectedPackage': {
              'type': 'string',
              'description': 'Paquete esperado para IME enter.',
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: false,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'launch_app',
        description:
            'Inicia una aplicación en primer plano a partir de su package name.',
        inputSchema: {
          'type': 'object',
          'required': ['packageName'],
          'properties': {
            'packageName': {
              'type': 'string',
              'description': 'Nombre del paquete Android.',
            },
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: false,
          idempotentHint: true,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'verify',
        description:
            'Verifica si la pantalla actual satisface postcondiciones de éxito esperadas.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'expectedPackage': {'type': 'string'},
            'mustAppearText': {'type': 'string'},
            'mustDisappearText': {'type': 'string'},
          },
        },
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
        ),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'get_ledger_history',
        description:
            'Consulta el historial de pasos operativos y resúmenes estructurados del TranscriptLedger.',
        inputSchema: {'type': 'object', 'properties': {}},
        annotations: McpToolAnnotations(
          readOnlyHint: true,
          idempotentHint: true,
          destructiveHint: false,
        ),
      ),
    ];
  }
}
