import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'nano_runtime_api.dart';
import 'sha256_file.dart';

part 'rootfs_manifest.dart';
part 'rootfs_installation.dart';
part 'rootfs_provenance.dart';
part 'rootfs_download_metadata.dart';
part 'rootfs_file_operations.dart';

/// Gestiona la instalación del rootfs Termux (bootstrap-aarch64.zip) en el
/// directorio privado de la app (`files/nano/`).
///
/// Flujo de vida:
///   1. isInstalled() → verifica si files/nano/usr/bin/bash existe y es ejecutable.
///   2. Si no está instalado, install() → LINUX-PROD-01: SHA-256 del PIN
///      (NanoRootfsManifest, jamás 'latest' en release), descarga el zip
///      (~31 MB), verifica hash (fail-closed) y extrae.
///   3. installStatus stream → reporta progreso (descarga, extracción, listo).
///
/// Después de instalar, ShellExecutor redirige sus paths a files/nano/usr/bin/
/// y el terminal usa un entorno Linux real con bash, coreutils, apt, dpkg...
class RootfsManager {
  /// Instancia global compartida. main.dart (auto-bootstrap al arrancar) y
  /// el terminal (ShellExecutor) usan la MISMA instancia: evita descargas
  /// duplicadas y mantiene el estado de instalación sincronizado.
  static RootfsManager? _shared;
  static RootfsManager get instance => _shared ??= RootfsManager();

  /// LINUX-PROD-01 — URL del release 'latest' dinámico. SOLO debug
  /// (NanoRootfsManifest.allowDynamicLatestInDebug); en release se usa el
  /// asset pinned del manifiesto.
  static const dynamicLatestBootstrapUrl =
      'https://github.com/termux/termux-packages/releases/latest/download/bootstrap-aarch64.zip';

  /// SHA256SUMS oficial del release termux-packages (debug/latest).
  /// Upstream dejó de publicar este asset en releases recientes (HTTP 404),
  /// se conserva como fallback legado por si vuelve a existir.
  static const sha256SumsUrl =
      'https://github.com/termux/termux-packages/releases/latest/download/SHA256SUMS';

  /// API de GitHub del release latest (debug/latest). Cada asset expone su
  /// SHA-256 en el campo `digest` (formato "sha256:<hex>").
  static const releasesApiUrl =
      'https://api.github.com/repos/termux/termux-packages/releases/latest';

  String? _usrDir;
  bool _installed = false;
  bool _downloading = false;
  String? _installedSourceTag;
  String? _verifiedArchiveHash;

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
      _installed = await NanoRuntimeApi.instance.isBootstrapInstalled(_usrDir!);
      if (_installed) _logInstalledVersion();
      return _installed;
    } catch (_) {
      _installed = false;
      return false;
    }
  }

  /// LINUX-PROD-01 — traza honesta del pin instalado: un rootfs de otro pin
  /// se conserva (jamás se pisa solo); el log dice qué versión hay.
  void _logInstalledVersion() {
    try {
      final usr = _usrDir;
      if (usr == null) return;
      final marker = File(
        '${usr.substring(0, usr.length - 4)}/rootfs-manifest.txt',
      );
      if (!marker.existsSync()) {
        debugPrint(
          '[rootfs] instalado sin marker (pre-pin o instalación manual) — '
          'pin actual=${NanoRootfsManifest.bootstrapTag}; conservado',
        );
        return;
      }
      final installedTag = marker.readAsLinesSync().firstOrNull ?? '';
      if (installedTag != NanoRootfsManifest.bootstrapTag) {
        debugPrint(
          '[rootfs] instalado=$installedTag pin actual='
          '${NanoRootfsManifest.bootstrapTag} — conservado; migrar requiere '
          'borrar files/nano/usr y reinstalar',
        );
      } else {
        debugPrint('[rootfs] pin verificado: $installedTag');
      }
    } on Object {
      // Marker ilegible: solo diagnóstico, nunca bloquea el arranque.
    }
  }

  /// Instala el rootfs si no está presente. Descarga y extrae el bootstrap.
  /// Retorna true si la instalación fue exitosa (o ya estaba instalado).
  ///
  /// Single-flight: main.dart (auto-bootstrap) y las sesiones del terminal
  /// llaman install() concurrentemente al arrancar. Sin lock, dos descargas
  /// escriben el MISMO zip mientras otra extracción lo lee → zip truncado →
  /// "extract_failed" y rootfs parcialmente instalado. Todas las llamadas
  /// concurrentes comparten una sola instalación.
  ///
  /// [extractor]: función que extrae [zipPath] a [destDir]. Si es null se usa
  /// el extractor Kotlin (fallback). La extracción PRINCIPAL debe ser el
  /// toybox unzip vía Nanoshell (dlopen): maneja symlinks y permisos Unix del
  /// zip Termux, cosa que ZipFile/ZipInputStream de Android no hacen bien.
  Future<bool>? _installInFlight;

  Future<bool> install({
    Future<int> Function(String zipPath, String destDir)? extractor,
  }) async {
    if (_installed) return true;
    if (_usrDir == null) await _resolveDirs();
    if (_usrDir == null) return false;

    // Verificar de nuevo por si ya se instaló en otra sesión
    if (await checkInstalled()) return true;

    // Coalesce concurrent installs into a single download+extract.
    _installInFlight ??= _doInstall(extractor: extractor);
    try {
      return await _installInFlight!;
    } finally {
      _installInFlight = null;
    }
  }
}
