import '../../platform/linux_tool_adapter.dart';
import '../platform_verification.dart';
import '../tool_call.dart';
import '../tool_registry.dart';

/// Manejador del subsistema Linux (C9).
/// Cumple SRP: ejecución segura y estructurada de comandos y operaciones de archivo en Linux.
class LinuxToolHandler {
  final LinuxToolAdapter? _adapter;
  final PlatformStateReader? _platformStateReader;

  const LinuxToolHandler({
    LinuxToolAdapter? adapter,
    PlatformStateReader? platformStateReader,
  })  : _adapter = adapter,
        _platformStateReader = platformStateReader;

  /// TER-AUT-02: true si [command] contiene operadores que solo bash puede
  /// interpretar (pipe, semicolon, AND/OR, subshell, redirect, heredoc).
  static bool hasShellOperators(String command) {
    return command.contains('|') ||
        command.contains(';') ||
        command.contains('&&') ||
        command.contains('||') ||
        command.contains(r'$(') ||
        command.contains('`') ||
        command.contains('>') ||
        command.contains('<') ||
        command.contains('\n');
  }

  /// Ejecuta un tool del subsistema Linux con resultado estructurado.
  Future<String> executeLinuxTool(ToolCall call, ToolRegistry registry) async {
    final adapter = _adapter;
    if (adapter == null) {
      return '[linuxOff] Subsistema Linux no disponible: sin distribución '
          'registrada o sin adaptador configurado.';
    }
    final pathArg = (call.args?['path'] as String?)?.trim();
    final commandArg = (call.args?['command'] as String?)?.trim();
    final arg = (pathArg != null && pathArg.isNotEmpty)
        ? pathArg
        : (commandArg != null && commandArg.isNotEmpty)
            ? commandArg
            : (call.textArg ?? call.selectorArg ?? '').trim();
    if (arg.isEmpty) {
      return '[tool] ${call.tool} requiere "path", "command", "text" o "selector" con el '
          'argumento.';
    }

    final def = registry.lookup(call.tool);
    final rawTimeout = call.args?['timeout'] is num
        ? (call.args!['timeout'] as num).toInt()
        : int.tryParse('${call.args?['timeout']}');
    final Duration? timeout;
    if (call.tool.toLowerCase() == 'linux.run' &&
        rawTimeout != null &&
        rawTimeout > 0) {
      final seconds = rawTimeout > 1000 ? (rawTimeout / 1000).round() : rawTimeout;
      timeout = Duration(seconds: seconds.clamp(1, 600));
    } else {
      timeout = def?.timeout;
    }
    final rawCwd = (call.args?['cwd'] as String?)?.trim();
    final cwd = (rawCwd != null && rawCwd.isNotEmpty) ? rawCwd : null;
    final envRaw = call.args?['environment'];
    final environment = envRaw is Map<String, dynamic>
        ? envRaw.map((k, v) => MapEntry(k, '$v'))
        : null;
    final LinuxCommandResult result;
    switch (call.tool.toLowerCase()) {
      case 'linux.list':
        result = await adapter.list(
          arg,
          cwd: cwd,
          environment: environment,
          timeout: timeout,
        );
      case 'linux.readfile':
        result = await adapter.readFile(
          arg,
          cwd: cwd,
          environment: environment,
          timeout: timeout,
        );
      case 'linux.writefile':
        final content = (call.args?['content'] as String?) ?? call.text ?? '';
        result = await adapter.writeFile(
          arg,
          content,
          cwd: cwd,
          environment: environment,
          timeout: timeout,
        );
      default:
        final extraArgs = call.args?['arguments'] ?? call.args?['args'];
        if (extraArgs is List && extraArgs.isNotEmpty) {
          final typedArgs = extraArgs.map((a) => a.toString()).toList();
          result = await adapter.runStructured(
            arg,
            typedArgs,
            cwd: cwd,
            environment: environment,
            timeout: timeout,
          );
        } else if (hasShellOperators(arg)) {
          result = await adapter.runCommand(
            arg,
            cwd: cwd,
            environment: environment,
            timeout: timeout,
          );
        } else {
          result = await adapter.runStructured(
            arg,
            const [],
            cwd: cwd,
            environment: environment,
            timeout: timeout,
          );
        }
    }
    if (!result.ok) {
      final err = (result.infrastructureError ?? result.stderr).trim();
      if (call.tool.toLowerCase() == 'linux.run' &&
          (err.contains('cancellation unconfirmed') ||
              (result.exitCode == -1 && err.contains('worker timeout')))) {
        return '[timeoutOutcomeUnknown] linux.run excedió el tiempo límite y su cancelación '
            'no pudo confirmarse de inmediato; resultado desconocido: $err';
      }
      return '[linux] ${result.infrastructureError}';
    }
    if (result.exitCode != null && result.exitCode != 0) {
      final err = result.stderr.trim();
      if (call.tool.toLowerCase() == 'linux.run' &&
          (err.contains('cancellation unconfirmed') ||
              (result.exitCode == -1 && err.contains('worker timeout')))) {
        return '[timeoutOutcomeUnknown] linux.run excedió el tiempo límite y su cancelación '
            'no pudo confirmarse de inmediato; resultado desconocido: $err';
      }
      return '[linux] comando terminó con exitCode=${result.exitCode}'
          '${err.isNotEmpty ? ': $err' : ''}';
    }
    if (call.tool == 'linux.writeFile' && _platformStateReader != null) {
      final r = await _platformStateReader.evaluate(FileExists(arg));
      if (r is PlatformPredicateSatisfied) {
        return 'Archivo escrito y verificado en "$arg".';
      }
    }
    final out = result.stdout.trim();
    final tail = out.length > 800 ? '${out.substring(0, 800)}…' : out;
    return 'Linux ${call.tool} →\n${tail.isEmpty ? '(sin salida)' : tail}';
  }
}
