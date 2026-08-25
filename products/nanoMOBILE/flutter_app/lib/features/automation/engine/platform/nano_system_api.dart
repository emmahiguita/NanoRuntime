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
import '../system/system_destination.dart';
import '../system/system_intent_launcher.dart';
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

  /// Abre un destino de sistema allowlisted. null = canal no respondió.
  Future<Map<dynamic, dynamic>?> openSystemDestination(String wireId) async {
    try {
      return await _system.invokeMethod<Map<dynamic, dynamic>>(
        'openSystemDestination',
        {'destination': wireId},
      );
    } catch (e) {
      debugPrint('[system] openSystemDestination error: $e');
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

/// Implementación MethodChannel de [SystemIntentLauncher]. Traduce un
/// [SystemDestination] semántico a su wire id; el nativo valida la allowlist.
class MethodChannelSystemIntentLauncher implements SystemIntentLauncher {
  MethodChannelSystemIntentLauncher({NanoSystemApi? api})
    : _api = api ?? NanoSystemApi.instance;

  final NanoSystemApi _api;

  @override
  Future<SystemIntentResult> open(SystemDestination destination) async {
    final raw = await _api.openSystemDestination(destination.wireId);
    if (raw == null) {
      return const SystemIntentResult.failure(
        SystemIntentError.unavailable,
        'Canal de sistema no disponible.',
      );
    }
    if (raw['opened'] == true) return const SystemIntentResult.ok();
    final err = raw['error'] as String? ?? '';
    return SystemIntentResult.failure(
      _mapError(err),
      'No se pudo abrir el destino: $err',
    );
  }

  SystemIntentError _mapError(String err) => switch (err) {
    'unsupported_destination' => SystemIntentError.unsupported,
    'launch_failed' => SystemIntentError.launchFailed,
    _ => SystemIntentError.unavailable,
  };
}
