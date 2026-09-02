/// Contrato del inventario de sistema (A2) — DIP.
///
/// Las capas domain/application dependen de [SystemInventory], NUNCA del
/// MethodChannel ni del PackageManager. [MethodChannelSystemInventory]
/// (engine/platform) implementa esta interfaz; los tests usan fakes.
library;

import 'system_models.dart';

/// Error tipado: la frontera nativa `com.nanoai/system` no respondió (canal
/// ausente, servicio no disponible, o error nativo). Nunca un
/// `Exception("falló")` genérico.
class SystemInventoryUnavailable implements Exception {
  const SystemInventoryUnavailable([
    this.reason = 'Canal de sistema no disponible.',
  ]);
  final String reason;

  @override
  String toString() => 'SystemInventoryUnavailable: $reason';
}

/// Inventario factual del dispositivo y sus apps launchable.
abstract interface class SystemInventory {
  Future<DeviceProfile> getDeviceProfile();

  Future<List<InstalledApp>> listLaunchableApps();

  Future<String?> getDefaultLauncher();
}
