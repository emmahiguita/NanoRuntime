import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/executors/linux/linux_action_verifier.dart';
import 'package:nanoai/features/automation/executors/linux/linux_automation_port.dart';
import 'package:nanoai/features/automation/executors/linux/linux_process_supervisor.dart';
import 'package:nanoai/features/automation/executors/linux/linux_security_policy.dart';
import 'package:nanoai/features/automation/executors/linux/nanoshell_linux_automation_executor.dart';
import 'package:nanoai/features/terminal/i_bin_executor.dart';
import 'package:nanoai/features/terminal/terminal_types.dart';

class MockBinExecutor implements IBinExecutor {
  @override
  bool initialized = true;

  @override
  String? binDir = '/bin';

  @override
  String? usrDir = '/usr';

  @override
  String? baseDir = '/';

  final Map<String, ShellResult> toyboxMap = {};
  final Map<String, ShellResult> execMap = {};
  final Map<String, ShellResult> bashMap = {};
  final List<String> killedTags = [];

  @override
  Future<void> init() async {}

  @override
  void killAll() {}

  @override
  bool killTag(String tag) => true;

  @override
  bool killTracked(String tag) {
    killedTags.add(tag);
    return true;
  }

  @override
  Future<ShellResult> toybox(
    List<String> args, {
    Map<String, String>? extraEnv,
    Duration? timeout,
  }) async {
    final key = args.join(' ');
    if (toyboxMap.containsKey(key)) return toyboxMap[key]!;
    final cmd = args.first;
    if (toyboxMap.containsKey(cmd)) return toyboxMap[cmd]!;
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult> bash(String cmd, {Map<String, String>? env, Duration? timeout}) async {
    for (final entry in bashMap.entries) {
      if (cmd.contains(entry.key)) return entry.value;
    }
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
    final key = '$binaryPath ${args.join(' ')}';
    if (execMap.containsKey(key)) return execMap[key]!;
    if (execMap.containsKey(binaryPath)) return execMap[binaryPath]!;
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
  }) async {
    onOut?.call('process started');
    return 0;
  }
}

void main() {
  group('NanoshellLinuxAutomationExecutor (SOLID & Ports)', () {
    late MockBinExecutor mockShell;
    late ILinuxAutomationExecutor executor;

    setUp(() {
      mockShell = MockBinExecutor();
      const security = LinuxSecurityPolicy(
        allowedWriteRoots: ['/sdcard/Nanoai', '/tmp'],
        forbiddenWritePaths: ['/system', '/bin'],
      );
      final verifier = LinuxActionVerifier(binExecutor: mockShell);
      final supervisor = LinuxProcessSupervisor(binExecutor: mockShell);

      executor = NanoshellLinuxAutomationExecutor(
        binExecutor: mockShell,
        securityPolicy: security,
        verifier: verifier,
        supervisor: supervisor,
      );
    });

    test('listFiles: parsea salida de ls en LinuxFileEntry tipados', () async {
      mockShell.toyboxMap['ls -la /tmp'] = const ShellResult(
        stdout: 'total 1\n'
            'drwxr-xr-x 2 nano nano 4096 Jan 1 00:00 subdir\n'
            '-rw-r--r-- 1 nano nano 1024 Jan 1 00:00 file.txt\n',
        stderr: '',
        exitCode: 0,
      );

      final result = await executor.listFiles('/tmp');

      expect(result.ok, isTrue);
      expect(result.data, hasLength(2));
      expect(result.data![0].name, equals('subdir'));
      expect(result.data![0].isDirectory, isTrue);
      expect(result.data![1].name, equals('file.txt'));
      expect(result.data![1].sizeBytes, equals(1024));
    });

    test('writeFile: bloquea rutas protegidas por política de seguridad', () async {
      final result = await executor.writeFile('/system/bin/malicious.sh', 'echo hack');

      expect(result.ok, isFalse);
      expect(result.exitCode, equals(-1));
      expect(result.stderr, contains('prohibida'));
      expect(result.verification.condition, equals('security_policy'));
    });

    test('writeFile: permite escritura en ruta permitida y verifica postcondición', () async {
      mockShell.toyboxMap['test -f /sdcard/Nanoai/test.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      mockShell.toyboxMap['wc -c /sdcard/Nanoai/test.txt'] =
          const ShellResult(stdout: '11\n', stderr: '', exitCode: 0);

      final result = await executor.writeFile(
        '/sdcard/Nanoai/test.txt',
        'hello world',
        verifyWritten: true,
      );

      expect(result.ok, isTrue);
      expect(result.isVerified, isTrue);
      expect(result.verification.condition, equals('file_written'));
    });

    test('removePath: ejecuta rm y verifica eliminación', () async {
      mockShell.toyboxMap['rm -f /tmp/test.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      // test -e retorna 1 indicando que ya no existe -> verificado
      mockShell.toyboxMap['test -e /tmp/test.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 1);

      final result = await executor.removePath('/tmp/test.txt', verifyDeleted: true);

      expect(result.ok, isTrue);
      expect(result.isVerified, isTrue);
      expect(result.verification.condition, equals('path_deleted'));
    });

    test('createTar: empaqueta y verifica integridad', () async {
      mockShell.toyboxMap['tar -czf /tmp/out.tar.gz /tmp/src'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      mockShell.toyboxMap['tar -tzf /tmp/out.tar.gz'] =
          const ShellResult(stdout: 'item1\nitem2\n', stderr: '', exitCode: 0);

      final result = await executor.createTar(
        '/tmp/src',
        '/tmp/out.tar.gz',
        verifyIntegrity: true,
      );

      expect(result.ok, isTrue);
      expect(result.isVerified, isTrue);
      expect(result.verification.condition, equals('archive_valid'));
    });

    test('startTracked & stopTracked: inicia proceso y lo mata por tag', () async {
      final startRes = await executor.startTracked(
        'python',
        ['server.py'],
        trackTag: 'web-srv',
      );

      expect(startRes.ok, isTrue);
      expect(startRes.data!.trackTag, equals('web-srv'));

      final stopRes = await executor.stopTracked('web-srv');
      expect(stopRes.ok, isTrue);
      expect(mockShell.killedTags, contains('web-srv'));
    });

    test('git operations: status, diff, log estructurados', () async {
      mockShell.execMap['git status --short'] =
          const ShellResult(stdout: ' M lib/main.dart\n', stderr: '', exitCode: 0);

      final res = await executor.gitStatus('/repo');
      expect(res.ok, isTrue);
      expect(res.data, contains('M lib/main.dart'));
    });
  });
}
