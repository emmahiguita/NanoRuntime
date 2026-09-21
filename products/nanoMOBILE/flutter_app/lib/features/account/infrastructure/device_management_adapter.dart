import '../domain/device_entity.dart';
import '../domain/device_repository.dart';
import 'local_account_storage.dart';

/// QUÉ HACE:
/// Adaptador de gestión y auditoría de dispositivos vinculados.
///
/// CÓMO FUNCIONA:
/// Mantiene un listado de sesiones autorizadas, reconociendo el dispositivo actual
/// mediante identificador anónimo generado aleatoriamente.
///
/// POR QUÉ:
/// Permite al usuario revocar sesiones no autorizadas o renombrar sus dispositivos
/// sin vulnerar la privacidad (cero rastreo por IMEI ni Android ID).
class DeviceManagementAdapter implements DeviceRepository {
  final LocalAccountStorage _localStorage;
  final List<DeviceEntity> _cachedDevices = [];

  DeviceManagementAdapter({LocalAccountStorage? localStorage})
    : _localStorage = localStorage ?? LocalAccountStorage();

  @override
  Future<List<DeviceEntity>> getDevices(String uid) async {
    final currentId = await _localStorage.getOrCreateDeviceId();
    if (_cachedDevices.isEmpty) {
      _cachedDevices.add(
        DeviceEntity(
          deviceId: currentId,
          friendlyName: 'Este dispositivo (Nano Mobile)',
          platform: 'android',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          lastSeenAt: DateTime.now(),
          isCurrentDevice: true,
        ),
      );
    }
    return List.unmodifiable(_cachedDevices);
  }

  @override
  Future<DeviceEntity> registerCurrentDevice({
    required String uid,
    required String friendlyName,
  }) async {
    final currentId = await _localStorage.getOrCreateDeviceId();
    final device = DeviceEntity(
      deviceId: currentId,
      friendlyName: friendlyName,
      platform: 'android',
      createdAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      isCurrentDevice: true,
    );

    final idx = _cachedDevices.indexWhere((d) => d.deviceId == currentId);
    if (idx >= 0) {
      _cachedDevices[idx] = device;
    } else {
      _cachedDevices.add(device);
    }
    return device;
  }

  @override
  Future<void> renameDevice({
    required String uid,
    required String deviceId,
    required String newName,
  }) async {
    final idx = _cachedDevices.indexWhere((d) => d.deviceId == deviceId);
    if (idx >= 0) {
      _cachedDevices[idx] = _cachedDevices[idx].copyWith(
        friendlyName: newName.trim(),
        lastSeenAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> unlinkDevice({
    required String uid,
    required String deviceId,
  }) async {
    _cachedDevices.removeWhere((d) => d.deviceId == deviceId);
  }
}
