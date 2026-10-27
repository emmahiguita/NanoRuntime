import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/bounded_process.dart';

void main() {
  test('Timeout termina el proceso real, no solo la espera', () async {
    final folder = await Directory.systemTemp.createTemp('nano-process-proof-');
    addTearDown(() => folder.delete(recursive: true));
    final pidFile = File('${folder.path}/pid.txt');
    final escaped = pidFile.path.replaceAll("'", "''");
    final exe = Platform.isWindows ? 'powershell.exe' : '/bin/sh';
    final args = Platform.isWindows
        ? [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "[System.IO.File]::WriteAllText('$escaped', [string]\$PID); Start-Sleep -Seconds 30",
          ]
        : ['-c', 'echo \$\$ > "${pidFile.path}"; exec sleep 30'];
    await expectLater(
      BoundedProcess.run(exe, args, timeout: const Duration(seconds: 3)),
      throwsA(isA<TimeoutException>()),
    );
    expect(await pidFile.exists(), isTrue);
    final pid = int.parse((await pidFile.readAsString()).trim());
    if (Platform.isWindows) {
      final check = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }',
      ]);
      expect(check.exitCode, 0);
    } else {
      final check = await Process.run('/bin/kill', ['-0', '$pid']);
      expect(check.exitCode, isNot(0));
    }
  });
}
