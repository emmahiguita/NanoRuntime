import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/executors/linux/linux_action_verifier.dart';
import 'package:nanoai/features/terminal/i_bin_executor.dart';
import 'package:nanoai/features/terminal/terminal_types.dart';

class FakeBinExecutor implements IBinExecutor {
  @override
  bool initialized = true;

  @override
  String? binDir = '/bin';

  @override
  String? usrDir = '/usr';

  @override
  String? baseDir = '/';

  final Map<String, ShellResult> toyboxResponses = {};
  final List<List<String>> executedToyboxCalls = [];

  @override
  Future<void> init() async {}

  @override
  void killAll() {}

  @override
  bool killTag(String tag) => true;

  @override
  bool killTracked(String tag) => true;

  @override
  Future<ShellResult> toybox(
    List<String> args, {
    Map<String, String>? extraEnv,
    Duration? timeout,
  }) async {
    executedToyboxCalls.add(args);
    final key = args.join(' ');
    if (toyboxResponses.containsKey(key)) {
      return toyboxResponses[key]!;
    }
    // Fallback por comando base
    final cmd = args.first;
    if (toyboxResponses.containsKey(cmd)) {
      return toyboxResponses[cmd]!;
    }
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult> bash(String cmd, {Map<String, String>? env, Duration? timeout}) async {
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult> execRootfs(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
    Duration? timeout,
  }) async {
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult?> execRootfsWorker(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
    Duration? timeout,
  }) async => null;

  @override
  Future<int> stream(
    String command,
    List<String> args, {
    String? workDir,
    Map<String, String>? env,
    void Function(String line)? onOut,
    void Function(String line)? onErr,
    Duration? timeout,
    String? trackTag,
  }) async => 0;
}

void main() {
  group('LinuxActionVerifier (EXECUTED ≠ VERIFIED)', () {
    late FakeBinExecutor fakeShell;
    late LinuxActionVerifier verifier;

    setUp(() {
      fakeShell = FakeBinExecutor();
      verifier = LinuxActionVerifier(binExecutor: fakeShell);
    });

    test('verifyExists: reporta satisfecho cuando test -e retorna 0', () async {
      fakeShell.toyboxResponses['test -e /tmp/test.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);

      final result = await verifier.verifyExists('/tmp/test.txt');

      expect(result.verified, isTrue);
      expect(result.condition, equals('path_exists'));
    });

    test('verifyExists: reporta fallido cuando test -e retorna != 0', () async {
      fakeShell.toyboxResponses['test -e /tmp/missing.txt'] =
          const ShellResult(stdout: '', stderr: 'No such file', exitCode: 1);

      final result = await verifier.verifyExists('/tmp/missing.txt');

      expect(result.verified, isFalse);
      expect(result.condition, equals('path_exists'));
    });

    test('verifyFileWritten: verifica existencia, tamaño mínimo y hash SHA256', () async {
      fakeShell.toyboxResponses['test -f /sdcard/Nanoai/doc.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      fakeShell.toyboxResponses['wc -c /sdcard/Nanoai/doc.txt'] =
          const ShellResult(stdout: '128 /sdcard/Nanoai/doc.txt\n', stderr: '', exitCode: 0);
      fakeShell.toyboxResponses['sha256sum /sdcard/Nanoai/doc.txt'] =
          const ShellResult(stdout: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  doc.txt\n', stderr: '', exitCode: 0);

      final result = await verifier.verifyFileWritten(
        '/sdcard/Nanoai/doc.txt',
        minBytes: 50,
        expectedSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      expect(result.verified, isTrue);
      expect(result.condition, equals('file_written'));
    });

    test('verifyFileWritten: falla si el tamaño es inferior al mínimo esperado', () async {
      fakeShell.toyboxResponses['test -f /sdcard/Nanoai/empty.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      fakeShell.toyboxResponses['wc -c /sdcard/Nanoai/empty.txt'] =
          const ShellResult(stdout: '0 /sdcard/Nanoai/empty.txt\n', stderr: '', exitCode: 0);

      final result = await verifier.verifyFileWritten(
        '/sdcard/Nanoai/empty.txt',
        minBytes: 10,
      );

      expect(result.verified, isFalse);
      expect(result.condition, equals('min_size'));
    });

    test('verifyDeleted: reporta satisfecho solo si test -e retorna != 0', () async {
      fakeShell.toyboxResponses['test -e /tmp/to_delete.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 1);

      final result = await verifier.verifyDeleted('/tmp/to_delete.txt');

      expect(result.verified, isTrue);
      expect(result.condition, equals('path_deleted'));
    });

    test('verifyArchiveIntegrity: certifica archivo tar válido por listado de entradas', () async {
      fakeShell.toyboxResponses['tar -tzf /tmp/backup.tar.gz'] =
          const ShellResult(stdout: 'file1.txt\nfile2.txt\n', stderr: '', exitCode: 0);

      final result = await verifier.verifyArchiveIntegrity('/tmp/backup.tar.gz', gzip: true);

      expect(result.verified, isTrue);
      expect(result.condition, equals('archive_valid'));
      expect(result.details, contains('2 entradas'));
    });
  });
}
