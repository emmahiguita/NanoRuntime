part of 'rootfs_manager.dart';

/// Operaciones de rootfs_installation: conserva límites y evidencia del instalador.
extension _RootfsInstallation on RootfsManager {
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
          : RootfsManager.dynamicLatestBootstrapUrl;
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
      _verifiedArchiveHash = actualHash;
      if (pinned) _installedSourceTag = NanoRootfsManifest.bootstrapTag;
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
}
