import 'dart:convert';
import '../execution/agent_json_payload.dart';
import 'mcp_tool.dart';

/// Extrae solo argumentos escritos explícitamente; no inventa rutas ni consultas.
abstract final class McpCandidateArguments {
  static bool matches(McpTool tool, String goal) {
    final text = goal.toLowerCase();
    if (text.contains(tool.name.toLowerCase()) ||
        text.contains(tool.id.toLowerCase())) {
      return true;
    }
    final phrases = <String, List<String>>{
      'nano-linux/nano.linux.fs.list': [
        'listar archivos',
        'lista los archivos',
      ],
      'nano-linux/nano.linux.fs.read': ['leer archivo', 'lee el archivo'],
      'nano-linux/nano.linux.fs.stat': ['información del archivo'],
      'nano-linux/nano.linux.git.status': [
        'estado de git',
        'estado del repositorio',
      ],
      'nano-linux/nano.linux.git.diff': [
        'cambios de git',
        'diferencias de git',
      ],
      'nano-linux/nano.linux.git.log': ['historial de git', 'commits de git'],
      'nano-linux/nano.linux.process.list': [
        'listar procesos',
        'lista los procesos',
      ],
      'device/diagnostics': [
        'diagnóstico del dispositivo',
        'diagnostico del dispositivo',
      ],
    };
    return phrases[tool.id]?.any(text.contains) ?? false;
  }

  static Map<String, Object?> extract(McpTool tool, String goal) {
    final start = goal.indexOf('{');
    if (start >= 0) {
      try {
        final payload = AgentJsonPayload.extract(goal.substring(start));
        final decoded = payload == null ? null : jsonDecode(payload);
        if (decoded is Map<String, dynamic>) return decoded;
      } on Object {
        return const {};
      }
    }
    // Rutas entre comillas o absolutas sin espacios; nunca usa un path predeterminado.
    final quoted = RegExp(r'''["']([^"']+)["']''').firstMatch(goal)?.group(1);
    final absolute = RegExp(r'/(?:[^\s,;]+)').firstMatch(goal)?.group(0);
    final path = quoted ?? absolute;
    if (path == null) return const {};
    if (tool.id.startsWith('nano-linux/nano.linux.git.')) {
      return {'repoPath': path};
    }
    if (tool.id.startsWith('nano-linux/nano.linux.fs.')) {
      return {'path': path};
    }
    return const {};
  }
}
