import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

/// Persiste la evidencia de integridad de un artefacto ya verificado.
///
/// El manifiesto evita recalcular SHA-256 en cada apertura. Si falta (por una
/// instalación antigua), [verify] calcula el hash una vez y lo crea.
abstract final class ModelIntegrity {
  static File manifestFor(File artifact) =>
      File('${artifact.path}.integrity.json');

  static Future<bool> verify(File artifact, String expectedSha256) async {
    if (!await artifact.exists() || expectedSha256.trim().isEmpty) return false;
    final size = await artifact.length();
    if (size <= 0) return false;

    final manifest = manifestFor(artifact);
    if (await manifest.exists()) {
      try {
        final data = jsonDecode(await manifest.readAsString());
        if (data is Map<String, dynamic> &&
            data['sha256'] == expectedSha256.toLowerCase() &&
            data['sizeBytes'] == size &&
            data['modifiedAtEpochMs'] ==
                (await artifact.lastModified()).millisecondsSinceEpoch) {
          return true;
        }
      } on FormatException {
        // Un manifiesto roto no acredita el archivo: se verifica de nuevo.
      }
    }

    final actual = await sha256Of(artifact);
    if (actual != expectedSha256.toLowerCase()) return false;
    await writeManifest(artifact, actual);
    return true;
  }

  /// Variante síncrona y barata para reconciliar resultados del escáner.
  /// Sin manifiesto no afirma que un nombre/tamaño equivalga al catálogo.
  static bool hasTrustedManifest(File artifact, String expectedSha256) {
    final manifest = manifestFor(artifact);
    if (!artifact.existsSync() || !manifest.existsSync()) return false;
    try {
      final data = jsonDecode(manifest.readAsStringSync());
      return data is Map<String, dynamic> &&
          data['sha256'] == expectedSha256.toLowerCase() &&
          data['sizeBytes'] == artifact.lengthSync() &&
          data['modifiedAtEpochMs'] ==
              artifact.lastModifiedSync().millisecondsSinceEpoch;
    } on Object {
      return false;
    }
  }

  static Future<String> sha256Of(File artifact) async =>
      (await crypto.sha256.bind(artifact.openRead()).first).toString();

  static Future<void> writeManifest(File artifact, String sha256) async {
    final manifest = manifestFor(artifact);
    final temporary = File('${manifest.path}.part');
    await temporary.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'sha256': sha256.toLowerCase(),
        'sizeBytes': await artifact.length(),
        'modifiedAtEpochMs':
            (await artifact.lastModified()).millisecondsSinceEpoch,
      }),
      flush: true,
    );
    if (await manifest.exists()) await manifest.delete();
    await temporary.rename(manifest.path);
  }
}
