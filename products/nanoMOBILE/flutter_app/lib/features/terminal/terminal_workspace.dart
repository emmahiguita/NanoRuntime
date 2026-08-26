import 'dart:io';

import '../../core/services/terminal_audit_logger.dart';

/// Owns terminal-local infrastructure that should not live in the widget tree:
/// - sandboxed real filesystem bootstrap
/// - demo seed files
/// - structured audit logger sink
class TerminalWorkspace {
  TerminalWorkspace({required this.sessionId});

  final int sessionId;

  late final TerminalAuditLogger audit;

  void init() {
    final hereDir = Directory('${Directory.systemTemp.path}/nano_real_root');
    if (!hereDir.existsSync()) hereDir.createSync(recursive: true);
    final here = hereDir.path.replaceAll(r'\', '/');
    for (final dir in ['models', 'workspace', 'logs']) {
      final target = Directory('$here/$dir');
      if (!target.existsSync()) target.createSync(recursive: true);
    }

    final workspaceMain = File('$here/workspace/main.dart');
    if (!workspaceMain.existsSync()) {
      workspaceMain.writeAsStringSync('void main() => runApp(NanoAIApp());\n');
    }

    final readme = File('$here/workspace/README.md');
    if (!readme.existsSync()) {
      readme.writeAsStringSync('# NanoAI\nMotor LLM Local\n');
    }

    // Sin archivos de modelo ni logs prefabricados: un .gguf vacío parecería
    // un modelo instalado y un log con timestamps inventados sería simulación.
    // El directorio models/ queda vacío hasta que algo real lo pueble.
    final config = File('$here/models/config.json');
    if (!config.existsSync()) {
      config.writeAsStringSync(
        '{"temperature":0.7,"top_p":0.9,"context":2048}',
      );
    }

    audit = TerminalAuditLogger(sink: File('$here/logs/terminal_audit.jsonl'));
    audit.event(
      'terminal.init.root_ready',
      layer: 'terminal',
      data: {'sessionId': sessionId, 'cwd': here},
    );
  }
}
