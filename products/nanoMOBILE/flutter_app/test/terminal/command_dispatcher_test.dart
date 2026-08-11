import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/terminal/terminal_types.dart';

void main() {
  group('TerminalCtx defaults', () {
    test('has expected default PATH', () {
      final ctx = TerminalCtx();
      expect(ctx.env['PATH'], contains('/usr/bin'));
    });

    test('has expected default HOME', () {
      final ctx = TerminalCtx();
      expect(ctx.env['HOME'], '/home/nanoai');
    });

    test('aliases resolve correctly', () {
      final ctx = TerminalCtx();
      expect(ctx.aliases['ll'], 'ls -la');
      expect(ctx.aliases['..'], 'cd ..');
    });

    test('cwd starts at default', () {
      final ctx = TerminalCtx();
      expect(ctx.cwd, '/home/nanoai');
    });
  });

  group('ShellResult model', () {
    test('constructed with named parameters', () {
      const r = ShellResult(stdout: 'ok', stderr: '', exitCode: 0);
      expect(r.stdout, 'ok');
      expect(r.exitCode, 0);
    });

    test('error result carries exit code and stderr', () {
      const r = ShellResult(
        stdout: '',
        stderr: 'command not found',
        exitCode: 127,
      );
      expect(r.exitCode, 127);
      expect(r.stderr, 'command not found');
    });
  });
}
