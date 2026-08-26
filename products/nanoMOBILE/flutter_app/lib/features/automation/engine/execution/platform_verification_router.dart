/// A14.5 — Router de lectura de estado de plataforma (DIP). El ActionVerifier
/// depende de [PlatformStateReader]; este router implementa esa interfaz
/// delegando a los responsables de dominio (app/Linux/Shizuku). Lee HECHOS
/// factuales, no añade autoridad.
///
/// Honestidad de visibilidad:
/// - app en primer plano y existencia de archivo son OBSERVABLES con la
///   infraestructura actual.
/// - visibilidad de procesos (PackageProcessAbsent) está RESTRINGIDA en
///   Android moderno; se declara no-observable en vez de asumir éxito.
/// - exitCode de un comando ya ejecutado y aceptación de un reply se verifican
///   en el executor (que posee el resultado estructurado), no re-observable
///   aquí → no-observable.
library;

import '../perception/nano_snapshot.dart';
import '../platform/linux_tool_adapter.dart';
import 'platform_verification.dart';

class PlatformVerificationRouter implements PlatformStateReader {
  PlatformVerificationRouter({
    required Future<NanoSnapshot?> Function() snapshotFn,
    LinuxToolAdapter? linuxAdapter,
  }) : _snapshotFn = snapshotFn,
       _linuxAdapter = linuxAdapter;

  final Future<NanoSnapshot?> Function() _snapshotFn;
  final LinuxToolAdapter? _linuxAdapter;

  @override
  Future<PlatformPredicateResult> evaluate(PlatformPredicate predicate) async {
    return switch (predicate) {
      ForegroundPackageEquals(:final packageName) => _foregroundEquals(
        packageName,
        expectForeground: true,
      ),
      PackageNotForeground(:final packageName) => _foregroundEquals(
        packageName,
        expectForeground: false,
      ),
      FileExists(:final path) => _fileExists(path),
      FileContentContains(:final path, :final content) => _fileContains(
        path,
        content,
      ),
      PackageProcessAbsent() => const PlatformPredicateUnavailable(
        'La visibilidad de procesos está restringida en Android moderno; '
        'no se puede afirmar de forma factual.',
      ),
      ProcessExitCodeEquals() => const PlatformPredicateUnavailable(
        'El exit code se verifica en el executor a partir del resultado '
        'estructurado, no es re-observable aquí.',
      ),
      NotificationReplyAccepted() => const PlatformPredicateUnavailable(
        'La aceptación de un reply solo la confirma RemoteInput en el '
        'executor; no es re-observable aquí.',
      ),
    };
  }

  Future<PlatformPredicateResult> _foregroundEquals(
    String packageName, {
    required bool expectForeground,
  }) async {
    final snap = await _snapshotFn();
    if (snap == null) {
      return const PlatformPredicateUnavailable(
        'Sin snapshot: canal de accesibilidad sin respuesta.',
      );
    }
    if (snap.package.isEmpty) {
      return const PlatformPredicateUnavailable(
        'La ventana en primer plano no expone su package.',
      );
    }
    final matches = snap.package == packageName;
    final ok = expectForeground ? matches : !matches;
    if (ok) {
      return PlatformPredicateSatisfied('primer plano=${snap.package}');
    }
    return PlatformPredicateUnsatisfied(
      expectForeground
          ? 'Package esperado "$packageName", en primer plano "${snap.package}".'
          : 'Package "$packageName" sigue en primer plano tras la acción.',
    );
  }

  Future<PlatformPredicateResult> _fileExists(String path) async {
    final adapter = _linuxAdapter;
    if (adapter == null) {
      return const PlatformPredicateUnavailable(
        'Subsistema Linux no disponible para verificar el archivo.',
      );
    }
    final result = await adapter
        .readFile(path)
        .catchError((_) => const LinuxCommandResult(duration: Duration.zero));
    if (!result.ok) {
      return PlatformPredicateUnsatisfied('No se pudo leer "$path".');
    }
    return PlatformPredicateSatisfied('archivo legible en "$path"');
  }

  Future<PlatformPredicateResult> _fileContains(
    String path,
    String content,
  ) async {
    final adapter = _linuxAdapter;
    if (adapter == null) {
      return const PlatformPredicateUnavailable(
        'Subsistema Linux no disponible para verificar el archivo.',
      );
    }
    final result = await adapter
        .readFile(path)
        .catchError((_) => const LinuxCommandResult(duration: Duration.zero));
    if (!result.ok) {
      return PlatformPredicateUnsatisfied('No se pudo leer "$path".');
    }
    if (!result.stdout.contains(content)) {
      return PlatformPredicateUnsatisfied(
        'El contenido de "$path" no contiene el texto esperado.',
      );
    }
    return PlatformPredicateSatisfied('contenido verificado en "$path"');
  }
}
