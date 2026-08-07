import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gestiona la instalación del rootfs Termux (bootstrap-aarch64.zip) en el
/// directorio privado de la app (`files/nano/`).
///
/// Flujo de vida:
///   1. isInstalled() → verifica si files/nano/usr/bin/bash existe y es ejecutable.
///   2. Si no está instalado, install() → descarga el zip (~30 MB) y lo extrae.
///   3. installStatus stream → reporta progreso (descarga, extracción, listo).
///
/// Después de instalar, ShellExecutor redirige sus paths a files/nano/usr/bin/
/// y el terminal usa un entorno Linux real con bash, coreutils, apt, dpkg...
class RootfsManager {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  /// Instancia global compartida. main.dart (auto-bootstrap al arrancar) y
  /// el terminal (ShellExecutor) usan la MISMA instancia: evita descargas
  /// duplicadas y mantiene el estado de instalación sincronizado.
  static RootfsManager? _shared;
  static RootfsManager get instance => _shared ??= RootfsManager();

  /// Bootstrap-aarch64.zip oficial del repo Termux.
  /// Redirect de GitHub releases — apunta a la última versión disponible.
  static const bootstrapUrl =
      'https://github.com/termux/termux-packages/releases/latest/download/bootstrap-aarch64.zip';

  String? _usrDir;
  bool _installed = false;
  bool _downloading = false;

  bool get isInstalled => _installed;
  bool get isDownloading => _downloading;
  String? get usrDir => _usrDir;

  /// Callbacks para progreso de instalación.
  final void Function(String stage, int pct)? onProgress;

  RootfsManager({this.onProgress});

  /// Verifica si el bootstrap ya fue instalado. Si no, devuelve false.
  /// El path exacto es files/nano/usr/bin/bash (el layout Termux estándar).
  Future<bool> checkInstalled() async {
    if (_usrDir == null) await _resolveDirs();
    try {
      final ok = await _channel.invokeMethod<bool>(
        'isBootstrapInstalled',
        _usrDir,
      );
      _installed = ok ?? false;
      return _installed;
    } catch (_) {
      _installed = false;
      return false;
    }
  }

  /// Instala el rootfs si no está presente. Descarga y extrae el bootstrap.
  /// Retorna true si la instalación fue exitosa (o ya estaba instalado).
  ///
  /// [extractor]: función que extrae [zipPath] a [destDir]. Si es null se usa
  /// el extractor Kotlin (fallback). La extracción PRINCIPAL debe ser el
  /// toybox unzip vía Nanoshell (dlopen): maneja symlinks y permisos Unix del
  /// zip Termux, cosa que ZipFile/ZipInputStream de Android no hacen bien.
  Future<bool> install({
    Future<int> Function(String zipPath, String destDir)? extractor,
  }) async {
    if (_installed) return true;
    if (_usrDir == null) await _resolveDirs();
    if (_usrDir == null) return false;

    // Verificar de nuevo por si ya se instaló en otra sesión
    if (await checkInstalled()) return true;

    _downloading = true;
    onProgress?.call('download', 0);

    try {
      // 1. Descargar bootstrap-aarch64.zip a files/nano/
      await _channel.invokeMethod('downloadBootstrap', bootstrapUrl);
      onProgress?.call('download', 100);

      // 2. Extraer en files/nano/usr/ → crea usr/bin/, usr/lib/, etc.
      // IMPORTANTE: el bootstrap es PREFIX-relative (bin/, etc/, lib/...).
      // El PREFIX Termux es "usr", así que el zip DEBE extraerse en
      // files/nano/usr/ (NO en files/nano/). Extraer en files/nano/ dejaba
      // bin/bash en files/nano/bin/bash y usr/bin/bash nunca existía.
      onProgress?.call('extract', 0);
      final usr = _usrDir!; // files/nano/usr
      final zipPath = '${usr.substring(0, usr.length - 4)}/bootstrap-aarch64.zip';
      final count = extractor != null
          ? await extractor(zipPath, usr)
          : await _extractKotlin(zipPath, usr);
      onProgress?.call('extract', 100);

      onProgress?.call('done', count);

      // 3. Verificar que bash quedó ejecutable
      _installed = await checkInstalled();
      return _installed;
    } catch (e) {
      // Registrar el error REAL (PlatformException del channel) — antes se
      // tragaba en silencio y el usuario veía solo "Falló la instalación".
      debugPrint('[rootfs] install falló: ${e.runtimeType}: $e');
      onProgress?.call('error', 0);
      return false;
    } finally {
      _downloading = false;
    }
  }

  /// Extracción vía channel Kotlin (fallback sin Nanoshell).
  Future<int> _extractKotlin(String zipPath, String baseDir) async {
    final result = await _channel.invokeMethod('extractBootstrap', {
      'zipPath': zipPath,
      'destDir': baseDir,
    });
    if (result is Map) {
      final v = result['filesExtracted'];
      return v is int ? v : 0;
    }
    return 0;
  }

  /// Resuelve files/nano/ (getFilesDir del MethodChannel) y deriva usrDir.
  Future<void> _resolveDirs() async {
    try {
      final base = await _channel.invokeMethod<String>('getFilesDir');
      if (base != null && base.isNotEmpty) {
        _usrDir = '$base/usr';
      }
    } catch (_) {
      _usrDir = null;
    }
  }
}
