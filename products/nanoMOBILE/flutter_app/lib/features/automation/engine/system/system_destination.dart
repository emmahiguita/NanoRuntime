/// SystemDestination (A3) — destino SEMÁNTICO de sistema Android.
///
/// NO es el string crudo del Intent (`android.provider.Settings`). La capa de
/// dominio no depende del Android SDK; el mapeo a `Settings.ACTION_*` vive en
/// la frontera nativa (allowlist).
///
/// A3 incluye SOLO los destinos que no existían ya en otro boundary
/// (`DevicePermissionsChannelHandler` ya abre accessibility/notification
/// listener/app details — no se duplican aquí).
library;

/// Naturaleza del intent: navegación (abrir una pantalla) vs. cambio de estado
/// (mutar). A3 solo implementa NAVIGACIÓN; el cambio de estado (p. ej.
/// `changeBluetoothState`) NO se implementa ni se representa disponible.
enum SystemIntentKind { navigation, stateChange }

enum SystemDestination {
  settings('settings', 'Ajustes del sistema'),
  wifiSettings('wifi_settings', 'Ajustes de Wi-Fi'),
  bluetoothSettings('bluetooth_settings', 'Ajustes de Bluetooth');

  /// Id que viaja por el canal `com.nanoai/system` (allowlist nativa).
  final String wireId;

  final String description;

  const SystemDestination(this.wireId, this.description);

  /// Convierte el id de wire a un destino tipado. null = destino desconocido
  /// (el llamador debe rechazar, nunca construir un intent arbitrario).
  static SystemDestination? fromWireId(String id) {
    for (final d in SystemDestination.values) {
      if (d.wireId == id) return d;
    }
    return null;
  }
}
