// dynamic_surface_store.dart
//
// Almacén en memoria y persistible de perfiles de superficie auto-reparados.
// - ¿Qué hace?: Guarda perfiles dinámicos aprendidos cuando una app se actualiza
//   y cambia sus selectores o textos nativos.
// - ¿Cómo funciona?: Mapea [packageName + SurfaceElementKind] a reglas aprendidas
//   [SurfaceElementProfile] y consulta primero estos perfiles antes que los estáticos.
// - ¿Por qué?: Evita modificar código Dart cada vez que WhatsApp, Telegram o Gmail
//   actualizan su interfaz en Google Play. Cumple SOLID (Open/Closed Principle).

library;

import '../semantic/semantic_role.dart';
import '../surface_profiles.dart';

/// Fuente de perfiles dinámicos con capacidad de aprendizaje y auto-reparación.
final class DynamicSurfaceStore implements SurfaceProfileSource {
  DynamicSurfaceStore({SurfaceProfileSource? fallback})
      : _fallback = fallback ?? const SurfaceProfileRegistry();

  final SurfaceProfileSource _fallback;
  final Map<String, Map<SurfaceElementKind, SurfaceElementProfile>> _dynamicCache = {};
  final Map<String, String> _packageVersions = {};

  /// Registra o actualiza una regla de superficie descubierta por auto-reparación.
  void registerHealedElement({
    required String packageName,
    required SurfaceElementKind kind,
    required Set<SemanticRole> roles,
    required List<String> terms,
    bool allowClickableContainer = false,
    String? appVersion,
  }) {
    final pkg = packageName.trim().toLowerCase();
    if (appVersion != null) updatePackageVersion(pkg, appVersion);
    final profile = SurfaceElementProfile(
      roles: roles,
      terms: terms,
      allowClickableContainer: allowClickableContainer,
    );
    _dynamicCache.putIfAbsent(pkg, () => {})[kind] = profile;
  }

  /// Registra la versión actual de la app. Si difiere de la versión previa, invalida
  /// las reglas dinámicas aprendidas para forzar una nueva validación en caliente.
  void updatePackageVersion(String packageName, String version) {
    final pkg = packageName.trim().toLowerCase();
    final prev = _packageVersions[pkg];
    if (prev != null && prev != version) {
      _dynamicCache.remove(pkg);
    }
    _packageVersions[pkg] = version;
  }

  /// Limpia la caché dinámica de un paquete si se requiere reiniciar el aprendizaje.
  void clearForPackage(String packageName) {
    _dynamicCache.remove(packageName.trim().toLowerCase());
    _packageVersions.remove(packageName.trim().toLowerCase());
  }

  @override
  List<ResolvedSurfaceProfile> resolve(
    String packageName,
    SurfaceElementKind kind,
  ) {
    final pkg = packageName.trim().toLowerCase();
    final dynamicProfile = _dynamicCache[pkg]?[kind];

    // Si existe una regla auto-reparada aprendida, se prioriza sobre el catálogo fijo
    if (dynamicProfile != null) {
      final learned = ResolvedSurfaceProfile(
        sourceProfileId: 'auto-healed:$pkg',
        roles: dynamicProfile.roles,
        terms: dynamicProfile.terms,
        allowClickableContainer: dynamicProfile.allowClickableContainer,
      );
      return [learned, ..._fallback.resolve(packageName, kind)];
    }

    return _fallback.resolve(packageName, kind);
  }

  /// Retorna si un paquete tiene reglas aprendidas activas.
  bool hasHealedProfiles(String packageName) =>
      _dynamicCache.containsKey(packageName.trim().toLowerCase());
}

/// Instancia singleton en memoria para el ciclo de vida de la aplicación.
final globalDynamicSurfaceStore = DynamicSurfaceStore();
