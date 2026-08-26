/// A14.3 — provider FACTUAL de Shizuku que lee el estado REAL del dispositivo
/// vía el canal nativo pasivo `queryShizukuStatus` (instalación + binder +
/// autorización). NUNCA abre diálogo, NUNCA ejecuta acciones privilegiadas.
///
/// `available` != `authorized` != `action authorized by user` != `safe` !=
/// `executed`. Este provider solo responde la disponibilidad. Si el canal no
/// responde (tests, desktop, runtime sin nativo) el estado es `unsupported`
/// — nunca se finge `available`.
library;

import 'package:nanoai/core/services/nano_runtime_api.dart';

import 'shizuku_availability.dart';

/// Implementación real del contrato [ShizukuAvailabilityProvider] sobre el
/// MethodChannel nativo `com.nanoai/device_permissions`.
class MethodChannelShizukuAvailabilityProvider
    implements ShizukuAvailabilityProvider {
  MethodChannelShizukuAvailabilityProvider({NanoRuntimeApi? api})
    : _api = api ?? NanoRuntimeApi.instance;

  final NanoRuntimeApi _api;

  @override
  Future<ShizukuAvailability> status() async {
    final raw = await _api.queryShizukuStatus();
    if (raw.isEmpty) {
      return const ShizukuAvailability(
        ShizukuStatus.unsupported,
        'Sin backend Shizuku (canal nativo no disponible).',
      );
    }

    final installed = raw['installed'] == true;
    final binderAlive = raw['binderAlive'] == true;
    final granted = raw['permissionGranted'] == true;

    if (!installed) {
      return const ShizukuAvailability(
        ShizukuStatus.notInstalled,
        'Shizuku no instalado en el dispositivo.',
      );
    }
    if (!binderAlive) {
      return const ShizukuAvailability(
        ShizukuStatus.serviceUnavailable,
        'Shizuku instalado pero servicio no disponible.',
      );
    }
    if (!granted) {
      return const ShizukuAvailability(
        ShizukuStatus.permissionRequired,
        'Shizuku vivo pero Nano no está autorizado.',
      );
    }
    return const ShizukuAvailability(
      ShizukuStatus.available,
      'Shizuku disponible y Nano autorizado.',
    );
  }
}
