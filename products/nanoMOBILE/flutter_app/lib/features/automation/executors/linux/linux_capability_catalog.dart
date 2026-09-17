import 'package:flutter/foundation.dart';

/// Definición declarativa de una capacidad o tool Linux para Nano y MCP.
@immutable
class LinuxToolDefinition {
  final String name;
  final String description;
  final String promptSyntax;
  final bool requiresConfirmation;
  final Duration timeout;

  const LinuxToolDefinition({
    required this.name,
    required this.description,
    required this.promptSyntax,
    this.requiresConfirmation = false,
    this.timeout = const Duration(seconds: 30),
  });
}

/// Catálogo canónico de capacidades del subsistema Linux en Nano.
///
/// Expone herramientas fuertemente tipadas para que el planificador (Planner/Koog),
/// el despachador (AgentToolDispatcher) y clientes MCP interactúen con Linux
/// sin recurrir a concatenaciones descontroladas de shell strings.
class LinuxCapabilityCatalog {
  const LinuxCapabilityCatalog();

  static const List<LinuxToolDefinition> definitions = [
    // ── FS ──
    LinuxToolDefinition(
      name: 'linux.fs.list',
      description: 'Lista archivos y subdirectorios de una ruta estructurada en Linux.',
      promptSyntax: '{"tool":"linux.fs.list","path":"<ruta_absoluta>","recursive":false}',
    ),
    LinuxToolDefinition(
      name: 'linux.fs.read',
      description: 'Lee el contenido textual de un archivo en Linux con límite opcional de bytes.',
      promptSyntax: '{"tool":"linux.fs.read","path":"<ruta_absoluta>","maxBytes":4096}',
    ),
    LinuxToolDefinition(
      name: 'linux.fs.write',
      description: 'Escribe contenido en un archivo y verifica su persistencia en disco.',
      promptSyntax: '{"tool":"linux.fs.write","path":"<ruta_absoluta>","content":"<texto>"}',
      requiresConfirmation: true,
    ),
    LinuxToolDefinition(
      name: 'linux.fs.remove',
      description: 'Elimina un archivo o directorio y certifica su desaparición.',
      promptSyntax: '{"tool":"linux.fs.remove","path":"<ruta_absoluta>","recursive":false}',
      requiresConfirmation: true,
    ),
    LinuxToolDefinition(
      name: 'linux.fs.copy',
      description: 'Copia un archivo o directorio hacia un destino seguro.',
      promptSyntax: '{"tool":"linux.fs.copy","source":"<origen>","destination":"<destino>"}',
      requiresConfirmation: true,
    ),
    LinuxToolDefinition(
      name: 'linux.fs.move',
      description: 'Mueve un archivo o directorio hacia un nuevo destino.',
      promptSyntax: '{"tool":"linux.fs.move","source":"<origen>","destination":"<destino>"}',
      requiresConfirmation: true,
    ),
    LinuxToolDefinition(
      name: 'linux.fs.stat',
      description: 'Obtiene metadatos (tamaño, tipo, permisos) de una ruta en Linux.',
      promptSyntax: '{"tool":"linux.fs.stat","path":"<ruta_absoluta>"}',
    ),

    // ── Archive ──
    LinuxToolDefinition(
      name: 'linux.archive.create',
      description: 'Empaqueta y comprime una ruta en formato tar/tar.gz verificando integridad.',
      promptSyntax: '{"tool":"linux.archive.create","sourcePath":"<origen>","tarPath":"<destino.tar.gz>"}',
      requiresConfirmation: true,
    ),
    LinuxToolDefinition(
      name: 'linux.archive.extract',
      description: 'Extrae un archivo tar/tar.gz hacia un directorio verificando destino.',
      promptSyntax: '{"tool":"linux.archive.extract","tarPath":"<archivo.tar.gz>","targetDir":"<directorio>"}',
      requiresConfirmation: true,
    ),

    // ── Process ──
    LinuxToolDefinition(
      name: 'linux.process.list',
      description: 'Lista los procesos activos en ejecución dentro del entorno Linux.',
      promptSyntax: '{"tool":"linux.process.list"}',
    ),
    LinuxToolDefinition(
      name: 'linux.process.start',
      description: 'Inicia un proceso en segundo plano con streaming y supervisión por tag.',
      promptSyntax: '{"tool":"linux.process.start","command":"<binario>","args":["<arg1>"],"trackTag":"<tag>"}',
      requiresConfirmation: true,
    ),
    LinuxToolDefinition(
      name: 'linux.process.stop',
      description: 'Detiene un proceso supervisado enviando señales de terminación controlada.',
      promptSyntax: '{"tool":"linux.process.stop","trackTag":"<tag>"}',
      requiresConfirmation: true,
    ),

    // ── Git ──
    LinuxToolDefinition(
      name: 'linux.git.status',
      description: 'Consulta el estado de cambios y branch en un repositorio Git.',
      promptSyntax: '{"tool":"linux.git.status","repoPath":"<ruta_repo>"}',
    ),
    LinuxToolDefinition(
      name: 'linux.git.diff',
      description: 'Obtiene el diff de modificaciones no confirmadas en un repositorio Git.',
      promptSyntax: '{"tool":"linux.git.diff","repoPath":"<ruta_repo>"}',
    ),
    LinuxToolDefinition(
      name: 'linux.git.log',
      description: 'Consulta los commits más recientes de un repositorio Git.',
      promptSyntax: '{"tool":"linux.git.log","repoPath":"<ruta_repo>","limit":5}',
    ),

    // ── Structured Exec ──
    LinuxToolDefinition(
      name: 'linux.exec.structured',
      description: 'Ejecuta un binario estructurado con argumentos explícitos y política de seguridad.',
      promptSyntax: '{"tool":"linux.exec.structured","executable":"<binario>","args":["<arg1>"]}',
      requiresConfirmation: true,
    ),
  ];

  /// Busca una definición por su nombre exacto o sinónimos.
  static LinuxToolDefinition? lookup(String name) {
    final lower = name.toLowerCase().trim();
    for (final def in definitions) {
      if (def.name.toLowerCase() == lower) {
        return def;
      }
    }
    return null;
  }
}
