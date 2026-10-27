part of 'rootfs_manager.dart';

/// Operaciones de rootfs_file_operations: conserva límites y evidencia del instalador.
extension _RootfsFileOperations on RootfsManager {
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
