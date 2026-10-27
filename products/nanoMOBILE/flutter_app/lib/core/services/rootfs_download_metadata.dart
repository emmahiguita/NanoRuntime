part of 'rootfs_manager.dart';

/// Operaciones de rootfs_download_metadata: conserva límites y evidencia del instalador.
extension _RootfsDownloadMetadata on RootfsManager {
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
        Uri.parse(RootfsManager.releasesApiUrl),
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
      _installedSourceTag = json['tag_name'] as String?;
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
      final response = await http.get(Uri.parse(RootfsManager.sha256SumsUrl));
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
}
