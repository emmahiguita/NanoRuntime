import 'device_entity.dart';

/// QUÉ HACE:
/// Puerto para la gestión de dispositivos vinculados al usuario (DevicePort).
///
/// CÓMO FUNCIONA:
/// Permite listar, registrar, renombrar y desvincular dispositivos asociados
/// a la cuenta del usuario en Firestore (`users/{uid}/devices/{deviceId}`).
///
/// POR QUÉ:
/// Garantiza control y visibilidad sobre las sesiones concurrentes de Nano
/// sin exponer datos sensibles ni hardware IDs prohibidos.
abstract class DeviceRepository {
  /// Lista todos los dispositivos vinculados al usuario.
  Future<List<DeviceEntity>> getDevices(String uid);

  /// Registra o actualiza el dispositivo actual en la lista del usuario.
  Future<DeviceEntity> registerCurrentDevice({
    required String uid,
    required String friendlyName,
  });

  /// Renombra un dispositivo vinculado.
  Future<void> renameDevice({
    required String uid,
    required String deviceId,
    required String newName,
  });

  /// Desvincula un dispositivo del usuario.
  Future<void> unlinkDevice({required String uid, required String deviceId});
}
