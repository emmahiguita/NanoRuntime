import '../../../../../core/services/nano_runtime_api.dart';
import '../platform_verification.dart';

/// Manejador de herramientas con privilegios Shizuku.
/// Cumple SRP: inspección y control privilegiado de paquetes Android.
class ShizukuToolHandler {
  final NanoRuntimeApi _runtime;

  ShizukuToolHandler({
    NanoRuntimeApi? runtime,
  }) : _runtime = runtime ?? NanoRuntimeApi.instance;

  /// Emparejamiento y solicitud de conexión con Shizuku.
  Future<String> grantShizuku() async {
    final shizuku = await _runtime.queryShizukuStatus();
    if (shizuku['installed'] != true) {
      return '[shizukuNotInstalled] Shizuku no está instalado en el dispositivo.';
    }
    final granted = await _runtime.shizukuRequestPermission();
    if (granted) {
      return 'Shizuku ya estaba autorizado. Conectado con privilegios.';
    }
    return 'Solicitud de conexión enviada. Toca "Permitir" en el diálogo de '
        'Shizuku y vuelve.';
  }

  /// Consulta metadatos de un paquete (read-only, `cmd package dump`).
  Future<String> queryPackage(String packageName) async {
    final pkg = packageName.trim();
    if (pkg.isEmpty ||
        pkg.length > 255 ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9._]*$').hasMatch(pkg)) {
      return '[tool] shizuku_query_package: paquete inválido.';
    }
    final shizuku = await _runtime.queryShizukuStatus();
    if (shizuku['installed'] != true) {
      return '[shizukuNotInstalled] Shizuku no está instalado. Instálalo y '
          'autoriza Nano para usar privilegios.';
    }
    if (shizuku['binderAlive'] != true ||
        shizuku['permissionGranted'] != true) {
      return '[shizukuNotAuthorized] Shizuku activo pero Nano no está '
          'autorizado. Autoriza en la app Shizuku.';
    }
    final result = await _runtime.shizukuQueryPackage(pkg);
    if (result['ok'] == true) {
      final out = (result['output'] as String? ?? '').trim();
      final tail = out.length > 1500 ? out.substring(0, 1500) : out;
      return 'Detalle de $pkg:\n${tail.isEmpty ? '(sin salida)' : tail}';
    }
    return '[shizukuQuery:${result['code']}] No se pudo consultar el paquete.';
  }

  /// Detener una aplicación vía Shizuku UserService.
  Future<String> forceStop(
    String packageName, {
    PlatformStateReader? platformStateReader,
  }) async {
    final pkg = packageName.trim();
    if (pkg.isEmpty ||
        pkg.length > 255 ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9._]*$').hasMatch(pkg)) {
      return '[tool] force_stop_package: paquete inválido.';
    }
    final shizuku = await _runtime.queryShizukuStatus();
    if (shizuku['installed'] != true) {
      return '[shizukuNotInstalled] Shizuku no está instalado en el dispositivo.';
    }
    if (shizuku['binderAlive'] != true ||
        shizuku['permissionGranted'] != true) {
      return '[shizukuNotAuthorized] Nano no está autorizado para Shizuku. '
          'Usa @conceder shizuku.';
    }
    final ok = await _runtime.shizukuForceStop(pkg);
    if (!ok) {
      return '[forceStop:failed] No se pudo solicitar la detención de "$pkg".';
    }
    if (platformStateReader != null) {
      final r = await platformStateReader.evaluate(PackageNotForeground(pkg));
      if (r is PlatformPredicateSatisfied) {
        return 'Detenida "$pkg" (verificado: dejó de estar en primer plano). '
            'Reversible: tócala para reabrirla.';
      }
      if (r is PlatformPredicateUnsatisfied) {
        return 'Detención solicitada de "$pkg", pero SIGUE en primer plano: '
            '${r.reason}.';
      }
    }
    return 'Detención solicitada de "$pkg". No se pudo verificar el estado '
        'del proceso (visibilidad restringida).';
  }

  /// Instala un APK local vía Shizuku.
  Future<String> install(String apkPath) async {
    if (apkPath.isEmpty) {
      return '[tool] install_package: ruta inválida.';
    }
    final shizuku = await _runtime.queryShizukuStatus();
    if (shizuku['installed'] != true) {
      return '[shizukuNotInstalled] Shizuku no está instalado en el dispositivo.';
    }
    if (shizuku['binderAlive'] != true ||
        shizuku['permissionGranted'] != true) {
      return '[shizukuNotAuthorized] Nano no está autorizado para Shizuku. '
          'Usa @conceder shizuku.';
    }
    final ok = await _runtime.shizukuInstall(apkPath);
    return ok
        ? 'Instalación solicitada para "$apkPath".'
        : '[install:failed] No se pudo instalar (¿ruta existe?).';
  }

  /// Concede un permiso runtime a una aplicación vía Shizuku.
  Future<String> grantPermission(String packageName, String permission) async {
    final shizuku = await _runtime.queryShizukuStatus();
    if (shizuku['installed'] != true) {
      return '[shizukuNotInstalled] Shizuku no está instalado en el dispositivo.';
    }
    if (shizuku['binderAlive'] != true ||
        shizuku['permissionGranted'] != true) {
      return '[shizukuNotAuthorized] Nano no está autorizado para Shizuku. '
          'Usa @conceder shizuku.';
    }
    final ok = await _runtime.shizukuGrantPermission(
      packageName,
      permission,
    );
    return ok
        ? 'Permiso "$permission" solicitado para "$packageName".'
        : '[grant:failed] No se pudo conceder el permiso.';
  }
}
