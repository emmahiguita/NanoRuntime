import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'nano_runtime_api.dart';
import 'sha256_file.dart';

/// LINUX-PROD-01 — NanoRootfsManifest: rootfs PINNED (nunca 'latest').
///
/// Un bootstrap upstream nuevo puede romper paths, linker, TERMUX_*, X11 o
/// el escritorio sin aviso. En producción Nano instala EXACTAMENTE este
/// release: tag + URL + SHA-256 verificados (hash del asset publicado,
/// re-verificado por descarga local al fijar el pin). El pin solo cambia con
/// un commit deliberado (bump + validación física), jamás por lo que
/// upstream publique hoy.
///
/// Escape hatch: en builds DEBUG (kDebugMode) se permite seguir el release
/// 'latest' dinámico para desarrollo; en release la constante pinned es la
/// ÚNICA ruta (fail-closed: sin red o hash distinto = instalación abortada).
class NanoRootfsManifest {
  /// Release exacto fijado (asset verificado el 2026-09-05).
  static const String bootstrapTag = 'bootstrap-2026.08.30-r1+apt.android-7';

  /// ABI soportada por este pin (el bootstrap de Nano es aarch64).
  static const String abi = 'aarch64';

  /// SHA-256 del asset bootstrap-aarch64.zip del tag fijado (verificado por
  /// descarga local + Get-FileHash al fijar; minúsculas).
  static const String bootstrapSha256 =
      '7e92f4c435d16207cdda63d5629e666ab98441f09eefa6a8423037ef13263346';

  /// URL del asset EXACTO (tag en el path, jamás /latest/ en release).
  static const String bootstrapUrl =
      'https://github.com/termux/termux-packages/releases/download/'
      '$bootstrapTag/bootstrap-aarch64.zip';

  /// Versionado de compatibilidad del pin (paths/linker/X11 del rootfs).
  static const int compatibilityVersion = 1;

  /// Android mínimo requerido por el pin (linker namespaces del proyecto).
  static const String minimumAndroidSdk = '26';

  /// true SOLO en debug: seguir 'latest' dinámico. En release siempre false
  /// (constante: el tree-shaker elimina la rama dinámica).
  static bool get allowDynamicLatestInDebug => kDebugMode;
}

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
      final marker = File('${usr.substring(0, usr.length - 4)}/rootfs-manifest.txt');
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

  Future<bool> _doInstall({
    Future<int> Function(String zipPath, String destDir)? extractor,
  }) async {
    _downloading = true;
    onProgress?.call('download', 0);

    try {
      // 1. SHA-256 esperado: PIN del manifiesto en release; en debug puede
      //    seguir el release dinámico (API GitHub digest → SHA256SUMS legado).
      //    Fail-closed intacto: sin hash esperado la instalación se aborta.
      onProgress?.call('verify', 0);
      final pinned = !NanoRootfsManifest.allowDynamicLatestInDebug;
      final expectedHash = pinned
          ? NanoRootfsManifest.bootstrapSha256
          : await _fetchExpectedSha256();
      final downloadUrl = pinned
          ? NanoRootfsManifest.bootstrapUrl
          : dynamicLatestBootstrapUrl;
      if (pinned) {
        debugPrint(
          '[rootfs] pin=${NanoRootfsManifest.bootstrapTag} '
          'abi=${NanoRootfsManifest.abi} comp=${NanoRootfsManifest.compatibilityVersion}',
        );
      }
      if (expectedHash == null) {
        onProgress?.call('error', 0);
        debugPrint(
          '[rootfs] No se pudo obtener el SHA-256 oficial. Instalación abortada por seguridad.',
        );
        return false;
      }
      debugPrint(
        '[rootfs] SHA256 esperado para bootstrap-aarch64.zip: $expectedHash',
      );
      onProgress?.call('verify', 50);

      // 2. Descargar bootstrap-aarch64.zip a files/nano/
      onProgress?.call('download', 0);
      await NanoRuntimeApi.instance.downloadBootstrap(downloadUrl);
      onProgress?.call('download', 100);

      // 3. Verificar SHA256 del zip descargado
      onProgress?.call('verify', 50);
      final usr = _usrDir!; // files/nano/usr
      final zipPath =
          '${usr.substring(0, usr.length - 4)}/bootstrap-aarch64.zip';
      final actualHash = await _computeSha256(zipPath);
      if (actualHash != expectedHash) {
        debugPrint('[rootfs] SHA256 mismatch del bootstrap!');
        debugPrint('  Esperado: $expectedHash');
        debugPrint('  Recibido: $actualHash');
        onProgress?.call('error', 0);
        // Eliminar zip corrupto
        try {
          File(zipPath).deleteSync();
        } catch (_) {}
        return false;
      }
      debugPrint('[rootfs] SHA256 verificado correctamente');
      onProgress?.call('verify', 100);

      // 4. Extraer en files/nano/usr/ → crea usr/bin/, usr/lib/, etc.
      // IMPORTANTE: el bootstrap es PREFIX-relative (bin/, etc/, lib/...).
      // El PREFIX Termux es "usr", así que el zip DEBE extraerse en
      // files/nano/usr/ (NO en files/nano/). Extraer en files/nano/ dejaba
      // bin/bash en files/nano/bin/bash y usr/bin/bash nunca existía.
      onProgress?.call('extract', 0);
      final count = extractor != null
          ? await extractor(zipPath, usr)
          : await _extractKotlin(zipPath, usr);
      onProgress?.call('extract', 100);

      // 5. Limpiar zip para ahorrar espacio
      try {
        File(zipPath).deleteSync();
      } catch (_) {}

      onProgress?.call('done', count);

      // 6. Verificar que bash quedó ejecutable
      _installed = await checkInstalled();
      if (_installed) await _writeManifestMarker();
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

  /// LINUX-PROD-01 — deja constancia del pin instalado (files/nano/
  /// rootfs-manifest.txt). Un rootfs previo de otro pin se CONSERVA (borrar
  /// y reinstalar para migrar): nunca se pisa una instalación con paquetes
  /// del usuario sin decisión explícita.
  Future<void> _writeManifestMarker() async {
    try {
      final usr = _usrDir;
      if (usr == null) return;
      final marker = File(
        '${usr.substring(0, usr.length - 4)}/rootfs-manifest.txt',
      );
      await marker.writeAsString(
        '${NanoRootfsManifest.bootstrapTag}\n'
        'abi=${NanoRootfsManifest.abi}\n'
        'sha256=${NanoRootfsManifest.bootstrapSha256}\n'
        'compat=${NanoRootfsManifest.compatibilityVersion}\n'
        'minAndroid=${NanoRootfsManifest.minimumAndroidSdk}\n',
      );
    } on Object catch (e) {
      debugPrint('[rootfs] marker no se pudo escribir: $e');
    }
  }

  /// Obtiene el SHA-256 esperado de bootstrap-aarch64.zip.
  ///
  /// BUG-8 FIX: el SHA256SUMS ya no se publica en el release latest de
  /// termux-packages (HTTP 404 — evidencia device 2026-08-15: la compuerta
  /// fail-closed bloqueaba la reinstalación del rootfs por no existir el
  /// archivo a verificar). Fuente primaria ahora: campo `digest` del asset
  /// en la API de GitHub (formato "sha256:<hex>"). Si la API falla, se
  /// intenta el SHA256SUMS legado; si ambos fallan, null → "Instalación
  /// abortada por seguridad". Fail-closed intacto.
  Future<String?> _fetchExpectedSha256() async {
    final apiHash = await _fetchHashFromGitHubApi();
    if (apiHash != null) return apiHash;
    return _fetchHashFromLegacySums();
  }

  /// Descarga el JSON de releases/latest y extrae el `digest` del asset
  /// bootstrap-aarch64.zip. Retorna el hex del SHA-256 o null si falla.
  Future<String?> _fetchHashFromGitHubApi() async {
    try {
      final response = await http.get(
        Uri.parse(releasesApiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          // GitHub API exige User-Agent; sin él responde HTTP 403.
          'User-Agent': 'nanoai-mobile-rootfs-installer',
        },
      );
      if (response.statusCode != 200) {
        debugPrint(
          '[rootfs] Error consultando releases API: HTTP ${response.statusCode}',
        );
        return null;
      }

      final json = jsonDecode(response.body);
      final assets = json['assets'];
      if (assets is! List) {
        debugPrint('[rootfs] releases API: sin lista de assets');
        return null;
      }
      for (final asset in assets) {
        if (asset is Map && asset['name'] == 'bootstrap-aarch64.zip') {
          final digest = asset['digest'];
          if (digest is String && digest.startsWith('sha256:')) {
            return digest.substring('sha256:'.length).toLowerCase();
          }
          debugPrint('[rootfs] asset sin digest sha256 utilizable: $digest');
          return null;
        }
      }
      debugPrint('[rootfs] No se encontró bootstrap-aarch64.zip en la API');
      return null;
    } catch (e) {
      debugPrint('[rootfs] Error procesando releases API: $e');
      return null;
    }
  }

  /// Fallback legado: descarga y parsea el archivo SHA256SUMS si upstream
  /// vuelve a publicarlo. Retorna el hash de bootstrap-aarch64.zip o null.
  Future<String?> _fetchHashFromLegacySums() async {
    try {
      final response = await http.get(Uri.parse(sha256SumsUrl));
      if (response.statusCode != 200) {
        debugPrint(
          '[rootfs] Error descargando SHA256SUMS: HTTP ${response.statusCode}',
        );
        return null;
      }

      final lines = LineSplitter.split(response.body);
      for (final line in lines) {
        if (line.contains('bootstrap-aarch64.zip')) {
          // Formato: <hash>  <filename>
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            return parts[0].trim();
          }
        }
      }
      debugPrint(
        '[rootfs] No se encontró hash para bootstrap-aarch64.zip en SHA256SUMS',
      );
      return null;
    } catch (e) {
      debugPrint('[rootfs] Error procesando SHA256SUMS: $e');
      return null;
    }
  }

  /// Calcula SHA256 de un archivo local.
  Future<String> _computeSha256(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[rootfs] Archivo no existe para SHA256: $filePath');
        return '';
      }

      // TER-32: hash streaming compartido (zip ~30MB sin picos de RAM).
      return await sha256File(filePath);
    } catch (e) {
      debugPrint('[rootfs] Error calculando SHA256: $e');
      return '';
    }
  }

  /// Extracción vía runtime Kotlin (fallback sin Nanoshell).
  Future<int> _extractKotlin(String zipPath, String baseDir) =>
      NanoRuntimeApi.instance.extractBootstrap(zipPath, baseDir);

  /// Resuelve files/nano/ (getFilesDir del runtime) y deriva usrDir.
  Future<void> _resolveDirs() async {
    try {
      final base = await NanoRuntimeApi.instance.getFilesDir();
      if (base != null && base.isNotEmpty) {
        _usrDir = '$base/usr';
      }
    } catch (_) {
      _usrDir = null;
    }
  }
}
