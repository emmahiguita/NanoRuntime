import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'nano_runtime_api.dart';

/// Gestiona la instalación del rootfs Termux (bootstrap-aarch64.zip) en el
/// directorio privado de la app (`files/nano/`).
///
/// Flujo de vida:
///   1. isInstalled() → verifica si files/nano/usr/bin/bash existe y es ejecutable.
///   2. Si no está instalado, install() → obtiene el SHA-256 oficial (API de GitHub, digest del asset), descarga el zip (~30 MB), verifica hash y extrae.
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

  /// Bootstrap-aarch64.zip oficial del repo Termux.
  /// Redirect de GitHub releases — apunta a la última versión disponible.
  static const bootstrapUrl =
      'https://github.com/termux/termux-packages/releases/latest/download/bootstrap-aarch64.zip';

  /// SHA256SUMS oficial del release termux-packages.
  /// Upstream dejó de publicar este asset en releases recientes (HTTP 404),
  /// se conserva como fallback legado por si vuelve a existir.
  static const sha256SumsUrl =
      'https://github.com/termux/termux-packages/releases/latest/download/SHA256SUMS';

  /// API de GitHub del release latest. Cada asset expone su SHA-256 en el
  /// campo `digest` (formato "sha256:<hex>") — la fuente de verificación
  /// actual, firmada por el repo oficial de Termux.
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
      return _installed;
    } catch (_) {
      _installed = false;
      return false;
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
      // 1. Obtener el SHA-256 oficial (API GitHub asset digest, con
      //    fallback al SHA256SUMS legado)
      onProgress?.call('verify', 0);
      final expectedHash = await _fetchExpectedSha256();
      if (expectedHash == null) {
        onProgress?.call('error', 0);
        debugPrint('[rootfs] No se pudo obtener el SHA-256 oficial. Instalación abortada por seguridad.');
        return false;
      }
      debugPrint('[rootfs] SHA256 esperado para bootstrap-aarch64.zip: $expectedHash');
      onProgress?.call('verify', 50);

      // 2. Descargar bootstrap-aarch64.zip a files/nano/
      onProgress?.call('download', 0);
      await NanoRuntimeApi.instance.downloadBootstrap(bootstrapUrl);
      onProgress?.call('download', 100);

      // 3. Verificar SHA256 del zip descargado
      onProgress?.call('verify', 50);
      final usr = _usrDir!; // files/nano/usr
      final zipPath = '${usr.substring(0, usr.length - 4)}/bootstrap-aarch64.zip';
      final actualHash = await _computeSha256(zipPath);
      if (actualHash != expectedHash) {
        debugPrint('[rootfs] SHA256 mismatch del bootstrap!');
        debugPrint('  Esperado: $expectedHash');
        debugPrint('  Recibido: $actualHash');
        onProgress?.call('error', 0);
        // Eliminar zip corrupto
        try { File(zipPath).deleteSync(); } catch (_) {}
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
      try { File(zipPath).deleteSync(); } catch (_) {}

      onProgress?.call('done', count);

      // 6. Verificar que bash quedó ejecutable
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
        debugPrint('[rootfs] Error consultando releases API: HTTP ${response.statusCode}');
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
        debugPrint('[rootfs] Error descargando SHA256SUMS: HTTP ${response.statusCode}');
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
      debugPrint('[rootfs] No se encontró hash para bootstrap-aarch64.zip en SHA256SUMS');
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

      final bytes = await file.readAsBytes();
      final digest = crypto.sha256.convert(bytes);
      return digest.toString();
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
