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

    final model = File('$here/models/qwen2.5-1.5b.gguf');
    if (!model.existsSync()) model.writeAsStringSync('');

    final config = File('$here/models/config.json');
    if (!config.existsSync()) {
      config.writeAsStringSync(
        '{"temperature":0.7,"top_p":0.9,"context":2048}',
      );
    }

    final runtimeLog = File('$here/logs/nanortime.log');
    if (!runtimeLog.parent.existsSync()) {
      runtimeLog.parent.createSync(recursive: true);
    }
    if (!runtimeLog.existsSync()) {
      runtimeLog.writeAsStringSync(
        '[14:32:01] Boot OK\n[14:32:02] madvise 24 layers\n[14:32:15] OOM Guard: 0',
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
