part of 'linux_automation_mcp_client.dart';

/// Catálogo de operaciones integradas; no anuncia extracción ni shell arbitrario.
List<McpRemoteTool> _linuxMcpCatalog() {
  const path = {
    'type': 'string',
    'minLength': 1,
    'maxLength': 4096,
    'pattern': '^/',
  };
  const flag = {'type': 'boolean'};
  McpRemoteTool tool(
    String suffix,
    String description,
    Map<String, Object?> properties,
    List<String> required, {
    bool read = true,
  }) => McpRemoteTool(
    serverId: LinuxAutomationMcpClient.serverId,
    name: 'nano.linux.$suffix',
    description: description,
    inputSchema: {
      'type': 'object',
      'properties': properties,
      'required': required,
      'additionalProperties': false,
    },
    annotations: McpToolAnnotations(readOnlyHint: read, destructiveHint: !read),
  );
  return [
    tool(
      'fs.list',
      'Explora una carpeta. Devuelve nombres, tipos y tamaños; no interpreta documentos.',
      {'path': path, 'recursive': flag},
      ['path'],
    ),
    tool(
      'fs.read',
      'Lee texto local (hasta 64 KiB). PDF e imágenes requieren su lector específico.',
      {
        'path': path,
        'maxBytes': {'type': 'integer', 'minimum': 1, 'maximum': 65536},
      },
      ['path'],
    ),
    tool(
      'fs.stat',
      'Consulta existencia, tipo, permisos y tamaño de una ruta.',
      {'path': path},
      ['path'],
    ),
    tool(
      'fs.write',
      'Guarda texto literal y comprueba su SHA-256. Puede sobrescribir; exige confirmación.',
      {
        'path': path,
        'content': {'type': 'string', 'maxLength': 65536},
      },
      ['path', 'content'],
      read: false,
    ),
    tool(
      'fs.copy',
      'Copia una ruta y comprueba el destino. Puede sobrescribir; exige confirmación.',
      {'source': path, 'destination': path},
      ['source', 'destination'],
      read: false,
    ),
    tool(
      'fs.move',
      'Mueve una ruta y comprueba el destino. Exige confirmación.',
      {'source': path, 'destination': path},
      ['source', 'destination'],
      read: false,
    ),
    tool(
      'archive.create',
      'Crea tar/tar.gz y comprueba que puede leerse su índice. Exige confirmación.',
      {'sourcePath': path, 'tarPath': path, 'gzip': flag},
      ['sourcePath', 'tarPath'],
      read: false,
    ),
    tool(
      'git.status',
      'Revisa archivos modificados de un repositorio explícito; necesita Git instalado.',
      {'repoPath': path},
      ['repoPath'],
    ),
    tool(
      'git.diff',
      'Lee diferencias sin modificar el repositorio. Salida extensa se marca parcial.',
      {'repoPath': path},
      ['repoPath'],
    ),
    tool(
      'git.log',
      'Consulta el historial de commits; no sincroniza ni publica cambios.',
      {
        'repoPath': path,
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
      },
      ['repoPath'],
    ),
    tool(
      'process.list',
      'Lee la tabla de procesos visible para Nano; Android limita su alcance.',
      {},
      [],
    ),
    tool(
      'process.inspect',
      'Consulta una tarea propiedad de Nano por etiqueta, su salida y finalización. No supone PID activo.',
      {
        'trackTag': {'type': 'string', 'minLength': 1, 'maxLength': 128},
      },
      ['trackTag'],
    ),
  ];
}
