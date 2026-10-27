import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'execution_budget.dart';

/// QUÉ: ejecuta un proceso auxiliar real sin dejarlo vivo tras timeout/cancelación.
/// CÓMO: consume ambas salidas con cupo y mata el proceso antes de liberar al dueño.
/// POR QUÉ: Process.run().timeout() solo abandona la espera; no detiene el hijo.
abstract final class BoundedProcess {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    ExecutionBudget.current?.check();
    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
    );
    void stop() {
      process.kill(ProcessSignal.sigkill);
    }

    void Function()? detach;
    final output = _collect(process.stdout), errors = _collect(process.stderr);
    try {
      detach = ExecutionBudget.current?.register(stop);
      final remaining = ExecutionBudget.current?.remaining;
      final wait = remaining != null && remaining < timeout
          ? remaining
          : timeout;
      final code = await process.exitCode.timeout(
        wait,
        onTimeout: () {
          stop();
          throw TimeoutException('Proceso auxiliar agotó su plazo');
        },
      );
      ExecutionBudget.current?.check();
      return ProcessResult(process.pid, code, await output, await errors);
    } finally {
      // Matar un proceso ya terminado no tiene efecto y no reutiliza su sesión.
      stop();
      detach?.call();
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );
      await Future.wait([
        output,
        errors,
      ]).timeout(const Duration(seconds: 2), onTimeout: () => ['', '']);
    }
  }

  static Future<String> _collect(Stream<List<int>> stream) async {
    final buffer = StringBuffer();
    var remaining = 64000;
    await for (final text in stream.transform(
      const Utf8Decoder(allowMalformed: true),
    )) {
      if (remaining <= 0) {
        continue; // Seguir drenando evita bloquear al proceso.
      }
      final selected = text.length > remaining
          ? text.substring(0, remaining)
          : text;
      buffer.write(selected);
      remaining -= selected.length;
    }
    return buffer.toString();
  }
}
