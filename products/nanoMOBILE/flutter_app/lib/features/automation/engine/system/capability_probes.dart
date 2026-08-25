/// CapabilityProbe (A3) — sondeo de availability de capabilities.
///
/// Cada probe lee UNA fuente factual y devuelve estados tipados. Añadir
/// Shizuku/ADB/root más adelante = añadir un probe nuevo, sin reescribir
/// [SystemGraph] ni [SystemGraphBuilder].
library;

import 'capability_availability.dart';
import 'system_capability.dart';

abstract interface class CapabilityProbe {
  Future<Map<SystemCapability, CapabilityAvailability>> probe();
}

/// Capabilities de inventario (A2) + futuras no implementadas.
class StaticSystemCapabilityProbe implements CapabilityProbe {
  const StaticSystemCapabilityProbe();

  @override
  Future<Map<SystemCapability, CapabilityAvailability>> probe() async {
    const pkg = SystemEvidence(
      SystemEvidenceSource.packageManager,
      'inventory',
    );
    const build = SystemEvidence(SystemEvidenceSource.deviceBuild, 'profile');
    const unsupported = CapabilityAvailabilityKind.unsupported;
    return {
      SystemCapability.readDeviceProfile: const CapabilityAvailability(
        capability: SystemCapability.readDeviceProfile,
        state: CapabilityAvailabilityKind.available,
        reason: 'DeviceProfile vía PackageManager/Build.',
        evidence: [build],
      ),
      SystemCapability.listLaunchableApps: const CapabilityAvailability(
        capability: SystemCapability.listLaunchableApps,
        state: CapabilityAvailabilityKind.available,
        reason: 'Apps launcher vía PackageManager.',
        evidence: [pkg],
      ),
      SystemCapability.launchApps: const CapabilityAvailability(
        capability: SystemCapability.launchApps,
        state: CapabilityAvailabilityKind.available,
        reason: 'Launch por Intent grounded en el catálogo (A2).',
        evidence: [pkg],
      ),
      // Futuras: sin backend en A3 — nunca `available`.
      for (final c in const [
        SystemCapability.mediaProjection,
        SystemCapability.developerAdb,
        SystemCapability.shizuku,
        SystemCapability.deviceOwner,
        SystemCapability.root,
      ])
        c: CapabilityAvailability(
          capability: c,
          state: unsupported,
          reason: 'No implementado en A3.',
        ),
    };
  }
}

/// Capabilities que dependen del AccessibilityService de Nano (device actions
/// y percepción/interacción de accesibilidad). `enabledFn` lee el estado real
/// (Settings.Secure), no "el código existe".
class AccessibilityCapabilityProbe implements CapabilityProbe {
  AccessibilityCapabilityProbe(this._enabledFn);

  final Future<bool> Function() _enabledFn;

  @override
  Future<Map<SystemCapability, CapabilityAvailability>> probe() async {
    final enabled = await _enabledFn();
    final state = enabled
        ? CapabilityAvailabilityKind.available
        : CapabilityAvailabilityKind.requiresAccessibility;
    const ev = SystemEvidence(
      SystemEvidenceSource.accessibilityService,
      'connected',
    );
    return {
      for (final c in const [
        SystemCapability.observeAccessibility,
        SystemCapability.interactAccessibility,
        SystemCapability.globalBack,
        SystemCapability.globalHome,
        SystemCapability.globalRecents,
        SystemCapability.openNotifications,
        SystemCapability.openQuickSettings,
      ])
        c: CapabilityAvailability(
          capability: c,
          state: state,
          reason: enabled
              ? 'AccessibilityService conectado.'
              : 'AccessibilityService de Nano no conectado.',
          evidence: const [ev],
        ),
    };
  }
}

/// Capabilities de notificaciones. `accessFn` lee el estado real de
/// NotificationListener (NotificationManagerCompat), no la mera existencia del
/// service en el APK.
class NotificationCapabilityProbe implements CapabilityProbe {
  NotificationCapabilityProbe(this._accessFn);

  final Future<bool> Function() _accessFn;

  @override
  Future<Map<SystemCapability, CapabilityAvailability>> probe() async {
    final access = await _accessFn();
    final state = access
        ? CapabilityAvailabilityKind.available
        : CapabilityAvailabilityKind.requiresNotificationAccess;
    const ev = SystemEvidence(
      SystemEvidenceSource.notificationListener,
      'access',
    );
    return {
      for (final c in const [
        SystemCapability.readNotifications,
        SystemCapability.replyNotifications,
      ])
        c: CapabilityAvailability(
          capability: c,
          state: state,
          reason: access
              ? 'Acceso a notificaciones habilitado.'
              : 'Acceso a notificaciones no habilitado.',
          evidence: const [ev],
        ),
    };
  }
}

/// Capability de ejecución Linux, basada en señal real de readiness (distros
/// registradas en el subsistema).
class LinuxCapabilityProbe implements CapabilityProbe {
  LinuxCapabilityProbe(this._availableFn);

  final bool Function() _availableFn;

  @override
  Future<Map<SystemCapability, CapabilityAvailability>> probe() async {
    final available = _availableFn();
    return {
      SystemCapability.linuxExecution: CapabilityAvailability(
        capability: SystemCapability.linuxExecution,
        state: available
            ? CapabilityAvailabilityKind.available
            : CapabilityAvailabilityKind.unavailable,
        reason: available
            ? 'Subsistema Linux disponible.'
            : 'Sin subsistema Linux registrado.',
        evidence: const [
          SystemEvidence(SystemEvidenceSource.linuxRuntime, 'distributions'),
        ],
      ),
    };
  }
}

/// Capabilities de destinos de sistema (navegación allowlisted A3). Disponibles
/// por ser intents oficiales del framework Android; la disponibilidad real del
/// destino se confirma al abrir (el verifier valida postcondición).
class SystemIntentCapabilityProbe implements CapabilityProbe {
  const SystemIntentCapabilityProbe();

  @override
  Future<Map<SystemCapability, CapabilityAvailability>> probe() async {
    const ev = SystemEvidence(SystemEvidenceSource.androidSdk, 'settings');
    return {
      for (final c in const [
        SystemCapability.openSystemSettings,
        SystemCapability.openWifiSettings,
        SystemCapability.openBluetoothSettings,
      ])
        c: CapabilityAvailability(
          capability: c,
          state: CapabilityAvailabilityKind.available,
          reason: 'Destino oficial de sistema (allowlist).',
          evidence: const [ev],
        ),
    };
  }
}
