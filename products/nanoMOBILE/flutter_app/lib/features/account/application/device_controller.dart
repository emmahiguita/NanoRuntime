import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/device_entity.dart';
import '../domain/device_repository.dart';

/// QUÉ HACE:
/// Gestiona la lista de dispositivos vinculados al usuario.
///
/// CÓMO FUNCIONA:
/// Obtiene y actualiza la lista de sesiones multi-dispositivo en tiempo real,
/// permitiendo al usuario revocar o renombrar terminales de forma segura.
///
/// POR QUÉ:
/// Cumple con la arquitectura multi-dispositivo (Mobile, Desktop, Web) de Nano.
class DeviceListState {
  final List<DeviceEntity> devices;
  final bool isLoading;
  final String? errorMessage;

  const DeviceListState({
    this.devices = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DeviceListState copyWith({
    List<DeviceEntity>? devices,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DeviceListState(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DeviceController extends StateNotifier<DeviceListState> {
  final DeviceRepository _repository;
  final String _uid;

  DeviceController({required DeviceRepository repository, required String uid})
    : _repository = repository,
      _uid = uid,
      super(const DeviceListState()) {
    loadDevices();
  }

  Future<void> loadDevices() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getDevices(_uid);
      state = state.copyWith(devices: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudieron cargar los dispositivos.',
      );
    }
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    try {
      await _repository.renameDevice(
        uid: _uid,
        deviceId: deviceId,
        newName: newName,
      );
      await loadDevices();
    } catch (_) {}
  }

  Future<void> unlinkDevice(String deviceId) async {
    try {
      await _repository.unlinkDevice(uid: _uid, deviceId: deviceId);
      await loadDevices();
    } catch (_) {}
  }
}
