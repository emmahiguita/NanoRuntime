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
    SystemDestination.displaySettings: SystemDestinationMeta(
      destination: SystemDestination.displaySettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.soundSettings: SystemDestinationMeta(
      destination: SystemDestination.soundSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.batterySaverSettings: SystemDestinationMeta(
      destination: SystemDestination.batterySaverSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.applicationSettings: SystemDestinationMeta(
      destination: SystemDestination.applicationSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.dateSettings: SystemDestinationMeta(
      destination: SystemDestination.dateSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.internalStorageSettings: SystemDestinationMeta(
      destination: SystemDestination.internalStorageSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.nfcSettings: SystemDestinationMeta(
      destination: SystemDestination.nfcSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.networkOperatorSettings: SystemDestinationMeta(
      destination: SystemDestination.networkOperatorSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.deviceInfoSettings: SystemDestinationMeta(
      destination: SystemDestination.deviceInfoSettings,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.camera: SystemDestinationMeta(
      destination: SystemDestination.camera,
      kind: SystemIntentKind.navigation,
    ),
    SystemDestination.dial: SystemDestinationMeta(
      destination: SystemDestination.dial,
      kind: SystemIntentKind.navigation,
    ),
  });
}
