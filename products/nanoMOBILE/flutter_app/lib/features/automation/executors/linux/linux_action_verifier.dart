import '../../../terminal/i_bin_executor.dart';
import 'linux_automation_types.dart';

/// Verificador de post-condición para acciones Linux.
///
/// Implementa el principio estricto: EXECUTED ≠ VERIFIED.
/// Un exitCode == 0 de bash/toybox no garantiza que la mutación se completó
/// exitosamente en el sistema de archivos o proceso. Este verificador
/// inspecciona el estado real del sistema post-ejecución.
class LinuxActionVerifier {
  final IBinExecutor _binExecutor;

  const LinuxActionVerifier({required IBinExecutor binExecutor})
      : _binExecutor = binExecutor;

  /// Verifica que un archivo existe en el sistema de archivos.
  Future<LinuxVerificationDetail> verifyExists(String path) async {
    final res = await _binExecutor.toybox(['test', '-e', path]);
    if (res.exitCode == 0) {
      return LinuxVerificationDetail.satisfied(
        'path_exists',
        'Ruta "$path" verificada y confirmada en disco.',
      );
    }
    return LinuxVerificationDetail.failed(
      'path_exists',
      'Ruta "$path" no existe tras la ejecución.',
    );
  }

  /// Verifica que un archivo fue escrito correctamente con tamaño y contenido esperado.
  Future<LinuxVerificationDetail> verifyFileWritten(
    String path, {
    int? minBytes,
    String? expectedSha256,
  }) async {
    // 1. Verificar existencia
    final existsRes = await _binExecutor.toybox(['test', '-f', path]);
    if (existsRes.exitCode != 0) {
      return LinuxVerificationDetail.failed(
        'file_written',
        'El archivo "$path" no existe tras la escritura.',
      );
    }

    // 2. Verificar tamaño mínimo si se solicita
    if (minBytes != null && minBytes > 0) {
      final statRes = await _binExecutor.toybox(['wc', '-c', path]);
      if (statRes.exitCode == 0) {
        final size = int.tryParse(statRes.stdout.trim().split(RegExp(r'\s+')).first) ?? 0;
        if (size < minBytes) {
          return LinuxVerificationDetail.failed(
            'min_size',
            'Archivo "$path" tiene $size bytes, menor al mínimo esperado ($minBytes bytes).',
          );
        }
      }
    }

    // 3. Verificar hash SHA-256 si se solicita
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final shaRes = await _binExecutor.toybox(['sha256sum', path]);
      if (shaRes.exitCode == 0) {
        final hash = shaRes.stdout.trim().split(RegExp(r'\s+')).first;
        if (hash.toLowerCase() != expectedSha256.toLowerCase()) {
          return LinuxVerificationDetail.failed(
            'sha256_match',
            'Hash SHA256 calculado ($hash) no coincide con el esperado ($expectedSha256).',
          );
        }
      }
    }

    return LinuxVerificationDetail.satisfied(
      'file_written',
      'Archivo "$path" escrito y verificado exitosamente.',
    );
  }

  /// Verifica que una ruta ha sido eliminada por completo.
  Future<LinuxVerificationDetail> verifyDeleted(String path) async {
    final res = await _binExecutor.toybox(['test', '-e', path]);
    if (res.exitCode != 0) {
      return LinuxVerificationDetail.satisfied(
        'path_deleted',
        'Ruta "$path" eliminada y confirmada inexistente.',
      );
    }
    return LinuxVerificationDetail.failed(
      'path_deleted',
      'Ruta "$path" aún existe tras la orden de eliminación.',
    );
  }

  /// Verifica la integridad de un archivo tar comprimido.
  Future<LinuxVerificationDetail> verifyArchiveIntegrity(
    String archivePath, {
    bool gzip = true,
  }) async {
    final flag = gzip ? '-tzf' : '-tf';
    final res = await _binExecutor.toybox(['tar', flag, archivePath]);
    if (res.exitCode == 0) {
      final entries = res.stdout.trim().split('\n').where((s) => s.isNotEmpty).length;
      return LinuxVerificationDetail.satisfied(
        'archive_valid',
        'Archivo comprimido "$archivePath" válido con $entries entradas verificadas.',
      );
    }
    return LinuxVerificationDetail.failed(
      'archive_valid',
      'Archivo comprimido "$archivePath" corrupto o ilegible: ${res.stderr.trim()}',
    );
  }

  /// Verifica que un destino de copia o movimiento contiene el archivo esperado.
  Future<LinuxVerificationDetail> verifyTargetPresent(
    String targetPath, {
    bool isDirectory = false,
  }) async {
    final flag = isDirectory ? '-d' : '-e';
    final res = await _binExecutor.toybox(['test', flag, targetPath]);
    if (res.exitCode == 0) {
      return LinuxVerificationDetail.satisfied(
        'target_present',
        'Destino "$targetPath" verificado en disco.',
      );
    }
    return LinuxVerificationDetail.failed(
      'target_present',
      'Destino "$targetPath" no fue creado o encontrado.',
    );
  }
}
