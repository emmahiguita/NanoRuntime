// depth_asset_cache.dart
//
// QUÉ HACE:
// Gestor y caché de mapas de profundidad asociados a productos comerciales.
// Mapea la ruta o ID de imagen original hacia su textura o archivo de profundidad correspondiente.
//
// CÓMO FUNCIONA:
// - Mantiene una caché en memoria rápida tipo LRU de rutas de mapas de profundidad.
// - Resuelve mapas de profundidad pre-generados o sintetizados en almacenamiento local.
// - Provee helpers deterministas para deducir la ruta esperada del mapa de profundidad.
//
// POR QUÉ:
// Evita recomputar o re-estimar mapas de profundidad en cada renderizado (eficiencia de CPU/batería)
// y aísla la resolución de archivos del componente visual en menos de 120 líneas.

library;

import 'dart:io';

class DepthAssetCache {
  // Caché en memoria: clave (ruta/ID imagen RGB) -> ruta archivo mapa de profundidad
  static final Map<String, String> _memoryCache = <String, String>{};

  const DepthAssetCache();

  /// Registra una asociación entre una imagen RGB y su mapa de profundidad en disco.
  void registerDepthPath({
    required String rgbMediaPath,
    required String depthMapPath,
  }) {
    if (rgbMediaPath.isEmpty || depthMapPath.isEmpty) return;
    _memoryCache[rgbMediaPath] = depthMapPath;
  }

  /// Consulta si existe un mapa de profundidad cacheado para la imagen indicada.
  String? getCachedDepthPath(String rgbMediaPath) {
    if (rgbMediaPath.isEmpty) return null;
    final cached = _memoryCache[rgbMediaPath];
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }
    return null;
  }

  /// Resuelve o infiere la ruta potencial del mapa de profundidad en el sistema de archivos.
  /// Convención: `producto_123.jpg` -> `producto_123_depth.png`
  String resolveExpectedDepthPath(String rgbMediaPath) {
    if (rgbMediaPath.isEmpty) return '';
    final dotIndex = rgbMediaPath.lastIndexOf('.');
    if (dotIndex == -1) return '${rgbMediaPath}_depth.png';
    final nameWithoutExt = rgbMediaPath.substring(0, dotIndex);
    return '${nameWithoutExt}_depth.png';
  }

  /// Verifica si el archivo esperado de profundidad existe físicamente en el disco.
  bool hasExistingDepthFile(String rgbMediaPath) {
    final expectedPath = resolveExpectedDepthPath(rgbMediaPath);
    final exists = File(expectedPath).existsSync();
    if (exists) {
      _memoryCache[rgbMediaPath] = expectedPath;
    }
    return exists;
  }

  /// Limpia la memoria caché volátil.
  void clear() {
    _memoryCache.clear();
  }
}
