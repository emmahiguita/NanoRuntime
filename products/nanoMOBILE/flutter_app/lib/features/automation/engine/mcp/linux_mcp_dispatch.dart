part of 'linux_automation_mcp_client.dart';

/// Cada nombre se conecta a una operación tipada existente, nunca a texto Bash generado.
extension _LinuxMcpDispatch on LinuxAutomationMcpClient {
  Future<McpToolCallResult> _dispatch(McpToolCall call) async {
    final a = call.arguments;
    switch (call.toolName) {
      case 'nano.linux.fs.list':
        final r = await _executor.listFiles(
          a['path'] as String,
          recursive: a['recursive'] == true,
        );
        return _linuxResult(
          r,
          data: {'entries': r.data?.map((e) => e.toJson()).toList()},
        );
      case 'nano.linux.fs.read':
        final max = a['maxBytes'] as int? ?? 4096;
        final r = await _executor.readFile(a['path'] as String, maxBytes: max);
        return _linuxResult(
          r,
          note: 'Lectura limitada a $max bytes; el archivo puede continuar.',
        );
      case 'nano.linux.fs.stat':
        final r = await _executor.statPath(a['path'] as String);
        return _linuxResult(r, data: {'entry': r.data?.toJson()});
      case 'nano.linux.fs.write':
        return _linuxResult(
          await _executor.writeFile(
            a['path'] as String,
            a['content'] as String,
          ),
        );
      case 'nano.linux.fs.copy':
        return _linuxResult(
          await _executor.copyPath(
            a['source'] as String,
            a['destination'] as String,
          ),
        );
      case 'nano.linux.fs.move':
        return _linuxResult(
          await _executor.movePath(
            a['source'] as String,
            a['destination'] as String,
          ),
        );
      case 'nano.linux.archive.create':
        return _linuxResult(
          await _executor.createTar(
            a['sourcePath'] as String,
            a['tarPath'] as String,
            gzip: a['gzip'] as bool? ?? true,
          ),
        );
      case 'nano.linux.git.status':
        return _linuxResult(await _executor.gitStatus(a['repoPath'] as String));
      case 'nano.linux.git.diff':
        return _linuxResult(await _executor.gitDiff(a['repoPath'] as String));
      case 'nano.linux.git.log':
        return _linuxResult(
          await _executor.gitLog(
            a['repoPath'] as String,
            limit: a['limit'] as int? ?? 10,
          ),
        );
      case 'nano.linux.process.list':
        final r = await _executor.listProcesses();
        return _linuxResult(
          r,
          data: {'processes': r.data?.map((p) => p.toJson()).toList()},
        );
      case 'nano.linux.process.inspect':
        final exec = _executor;
        if (exec is! LinuxProcessInspector) {
          return const McpToolCallResult(
            status: McpOperationStatus.unsupported,
            message: 'Este motor no publica tareas rastreadas.',
          );
        }
        final data = (exec as LinuxProcessInspector).inspectTracked(
          a['trackTag'] as String,
        );
        return McpToolCallResult(
          status: McpOperationStatus.success,
          structuredContent: data,
          content: [McpContentItem(type: 'text', text: jsonEncode(data))],
        );
      default:
        return const McpToolCallResult(
          status: McpOperationStatus.unsupported,
          message: 'Operación sin adaptador.',
        );
    }
  }
}
