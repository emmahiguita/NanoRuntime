/// SystemIntentCatalog (A3) — metadatos de destinos de sistema allowlisted.
///
/// Responde "¿qué destination oficial existe y qué naturaleza tiene?" (NAVEGACIÓN
/// vs. cambio de estado). NO consulta PackageManager directamente y NO ejecuta
/// intents: es metadatos de dominio. El mapeo a `Settings.ACTION_*` vive en la
/// frontera nativa (allowlist).
library;

import 'system_destination.dart';

class SystemDestinationMeta {
  final SystemDestination destination;
  final SystemIntentKind kind;

  /// true si el destino exige un package grounded (A3: ninguno — `appDetails`
  /// vive en DevicePermissionsChannelHandler).
  final bool requiresPackageInput;

  const SystemDestinationMeta({
    required this.destination,
    required this.kind,
    this.requiresPackageInput = false,
  });
}

/// Catálogo de destinos de sistema. A3 solo contiene NAVEGACIÓN (open); el
/// cambio de estado (`changeBluetoothState`) NO existe aquí ni se reporta
/// disponible.
class SystemIntentCatalog {
  final Map<SystemDestination, SystemDestinationMeta> _entries;

  const SystemIntentCatalog(this._entries);

  SystemDestinationMeta? metaFor(SystemDestination destination) =>
      _entries[destination];

  bool isKnown(SystemDestination destination) =>
      _entries.containsKey(destination);

  List<SystemDestination> get destinations => List.unmodifiable(_entries.keys);

  static const SystemIntentCatalog builtin = SystemIntentCatalog({
    SystemDestination.settings: SystemDestinationMeta(
      destination: SystemDestination.settings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.wifiSettings: SystemDestinationMeta(
      destination: SystemDestination.wifiSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.bluetoothSettings: SystemDestinationMeta(
      destination: SystemDestination.bluetoothSettings,
      kind: SystemIntentKind.navigation,
    ),
  });
}
