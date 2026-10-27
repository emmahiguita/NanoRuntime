part of 'rootfs_manager.dart';

/// Operaciones de rootfs_provenance: conserva límites y evidencia del instalador.
extension _RootfsProvenance on RootfsManager {
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
        '${_installedSourceTag ?? "origen-sin-etiqueta"}\n'
        'abi=${NanoRootfsManifest.abi}\n'
        'sha256=${_verifiedArchiveHash ?? "no-registrado"}\n'
        'compat=${NanoRootfsManifest.compatibilityVersion}\n'
        'minAndroid=${NanoRootfsManifest.minimumAndroidSdk}\n',
      );
    } on Object catch (e) {
      debugPrint('[rootfs] marker no se pudo escribir: $e');
    }
  }
}
