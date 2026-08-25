/// Modelos factuales del dispositivo y sus aplicaciones (A2).
///
/// Capa pura: sin MethodChannel. Los mapas vienen del canal `com.nanoai/system`
/// y aquí se convierten a tipos seguros para el catálogo y (futuro) SystemGraph.
///
/// IMPORTANTE — identidad != acceso: reconocer `com.whatsapp` NO significa que
/// Nano pueda leer sus archivos, notificaciones o UI. [InstalledApp] modela
/// identidad y launchability; el acceso es una capacidad y política separada.
library;

/// Perfil factual del dispositivo.
class DeviceProfile {
  final String manufacturer;
  final String model;
  final int sdkInt;
  final String release;

  /// Package del launcher por defecto (HOME). null si no resoluble.
  final String? defaultLauncherPackage;

  const DeviceProfile({
    required this.manufacturer,
    required this.model,
    required this.sdkInt,
    required this.release,
    this.defaultLauncherPackage,
  });

  factory DeviceProfile.fromMap(Map<dynamic, dynamic> m) => DeviceProfile(
    manufacturer: m['manufacturer'] as String? ?? '',
    model: m['model'] as String? ?? '',
    sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
    release: m['release'] as String? ?? '',
    defaultLauncherPackage: m['defaultLauncherPackage'] as String?,
  );
}

/// Aplicación instalada y launchable (identidad factual, NO acceso).
class InstalledApp {
  final String packageName;
  final String label;
  final String? versionName;
  final int? versionCode;
  final bool enabled;
  final bool system;
  final bool launchable;

  const InstalledApp({
    required this.packageName,
    required this.label,
    this.versionName,
    this.versionCode,
    required this.enabled,
    required this.system,
    required this.launchable,
  });

  /// true si es un candidato válido de launch: visible + habilitada + launchable.
  bool get isLaunchCandidate => launchable && enabled && packageName.isNotEmpty;

  factory InstalledApp.fromMap(Map<dynamic, dynamic> m) => InstalledApp(
    packageName: m['packageName'] as String? ?? '',
    label: m['label'] as String? ?? '',
    versionName: m['versionName'] as String?,
    versionCode: (m['versionCode'] as num?)?.toInt(),
    enabled: m['enabled'] == true,
    system: m['systemApp'] == true,
    launchable: m['launchable'] == true,
  );
}
