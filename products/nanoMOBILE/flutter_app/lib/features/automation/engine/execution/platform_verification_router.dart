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
    Future<Map<dynamic, dynamic>> Function()? systemStateSource,
  }) : _snapshotFn = snapshotFn,
       _linuxAdapter = linuxAdapter,
       _systemStateSource = systemStateSource;

  final Future<NanoSnapshot?> Function() _snapshotFn;
  final LinuxToolAdapter? _linuxAdapter;
  final Future<Map<dynamic, dynamic>> Function()? _systemStateSource;

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
      // A14.5.4 — predicados de estado semántico.
      MediaPlaybackStateEquals(:final playing) => _mediaPlaybackEquals(playing),
      ToggleStateEquals(:final toggle, :final enabled) => _toggleEquals(
        toggle,
        enabled,
      ),
      TextFieldContains(:final text, :final caseSensitive) => _fieldContains(
        text,
        caseSensitive,
      ),
      ConversationOpenEquals(:final packageName) => _foregroundEquals(
        packageName,
        expectForeground: true,
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

  Future<PlatformPredicateResult> _mediaPlaybackEquals(bool playing) async {
    final source = _systemStateSource;
    if (source == null) {
      return const PlatformPredicateUnavailable(
        'Sin lector de estado del sistema (media).',
      );
    }
    final state = await source();
    final actual = state['mediaPlaying'] == true;
    if (actual == playing) {
      return PlatformPredicateSatisfied('mediaPlaying=$actual');
    }
    return PlatformPredicateUnsatisfied(
      'Se esperaba mediaPlaying=$playing, real=$actual.',
    );
  }

  Future<PlatformPredicateResult> _toggleEquals(
    SystemToggle toggle,
    bool enabled,
  ) async {
    final source = _systemStateSource;
    if (source == null) {
      return const PlatformPredicateUnavailable(
        'Sin lector de estado del sistema (toggle).',
      );
    }
    final state = await source();
    final actual = switch (toggle) {
      SystemToggle.bluetooth => state['bluetoothEnabled'] == true,
      SystemToggle.wifi => state['wifiEnabled'] == true,
    };
    if (actual == enabled) {
      return PlatformPredicateSatisfied('${toggle.name}=$actual');
    }
    return PlatformPredicateUnsatisfied(
      'Se esperaba ${toggle.name}=$enabled, real=$actual.',
    );
  }

  Future<PlatformPredicateResult> _fieldContains(
    String text,
    bool caseSensitive,
  ) async {
    final snap = await _snapshotFn();
    if (snap == null) {
      return const PlatformPredicateUnavailable(
        'Sin snapshot para leer el campo de texto.',
      );
    }
    final needle = caseSensitive ? text : text.toLowerCase();
    for (final node in snap.visibleNodes) {
      final t = caseSensitive ? node.text : node.text.toLowerCase();
      if (t.contains(needle)) {
        return PlatformPredicateSatisfied('campo/texto contiene "$text"');
      }
    }
    return PlatformPredicateUnsatisfied(
      'Ningún nodo de texto contiene "$text".',
    );
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
    if (result.infrastructureError != null) {
      return PlatformPredicateUnsatisfied('No se pudo leer "$path".');
    }
    // T1.5: `cat` con exitCode != 0 = archivo inexistente/ilegible. El backend
    // factual (ShellExecutor) expone exitCode real, así que distinguimos
    // "existe" de "no existe" en vez de asumir legible por mero `ok`.
    if (result.exitCode != 0) {
      return PlatformPredicateUnsatisfied(
        'Archivo inexistente o ilegible en "$path".',
      );
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
    if (result.infrastructureError != null) {
      return PlatformPredicateUnsatisfied('No se pudo leer "$path".');
    }
    if (result.exitCode != 0) {
      return PlatformPredicateUnsatisfied(
        'Archivo inexistente o ilegible en "$path".',
      );
    }
    if (!result.stdout.contains(content)) {
      return PlatformPredicateUnsatisfied(
        'El contenido de "$path" no contiene el texto esperado.',
      );
    }
    return PlatformPredicateSatisfied('contenido verificado en "$path"');
  }
}
