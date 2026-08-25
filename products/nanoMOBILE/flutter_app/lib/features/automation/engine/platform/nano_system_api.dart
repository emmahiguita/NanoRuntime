/// Frontera nativa del inventario de sistema (A2).
///
/// [NanoSystemApi] es el transporte MethodChannel puro (DTO maps). La
/// implementación [MethodChannelSystemInventory] mapea DTOs a domain models y
/// cumple [SystemInventory]. El motor NO ve el MethodChannel: ve la interfaz.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/nano_runtime_api.dart'
    show NanoRuntimeChannels;
import '../system/system_inventory.dart';
import '../system/system_models.dart';

/// Fachada MethodChannel del canal `com.nanoai/system`.
class NanoSystemApi {
  static final NanoSystemApi instance = NanoSystemApi();
  static const _system = MethodChannel(NanoRuntimeChannels.system);

  Future<Map<dynamic, dynamic>?> getDeviceProfile() async {
    try {
      return await _system.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceProfile',
      );
    } catch (e) {
      debugPrint('[system] getDeviceProfile error: $e');
      return null;
    }
  }

  /// null = canal no respondió (distingue de lista vacía, que es válida).
  Future<List<dynamic>?> listLaunchableApps() async {
    try {
      return await _system.invokeListMethod<dynamic>('listLaunchableApps');
    } catch (e) {
      debugPrint('[system] listLaunchableApps error: $e');
      return null;
    }
  }

  Future<String?> getDefaultLauncher() async {
    try {
      return await _system.invokeMethod<String>('getDefaultLauncher');
    } catch (e) {
      debugPrint('[system] getDefaultLauncher error: $e');
      return null;
    }
  }
}

/// Implementación MethodChannel de [SystemInventory].
class MethodChannelSystemInventory implements SystemInventory {
  MethodChannelSystemInventory({NanoSystemApi? api})
    : _api = api ?? NanoSystemApi.instance;

  final NanoSystemApi _api;

  @override
  Future<DeviceProfile> getDeviceProfile() async {
    final raw = await _api.getDeviceProfile();
    if (raw == null) throw const SystemInventoryUnavailable();
    return DeviceProfile.fromMap(raw);
  }

  @override
  Future<List<InstalledApp>> listLaunchableApps() async {
    final raw = await _api.listLaunchableApps();
    if (raw == null) throw const SystemInventoryUnavailable();
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(InstalledApp.fromMap)
        .toList(growable: false);
  }

  @override
  Future<String?> getDefaultLauncher() => _api.getDefaultLauncher();
}
