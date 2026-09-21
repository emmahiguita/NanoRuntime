import 'dart:io';

import '../../../../core/services/device_metrics.dart';
import '../../../../core/services/nano_runtime_api.dart';
import 'nano_operating_tier.dart';
import 'system_inventory.dart';
import 'system_models.dart';

/// Resultado del diagnóstico factual de capacidades del dispositivo.
class UniversalDeviceSnapshot {
  final String manufacturer;
  final String model;
  final int sdkInt;
  final String release;
  final String cpuAbi;
  final double ramTotalGb;
  final double ramAvailableGb;
  final bool accessibilityActive;
  final bool canCaptureScreenshot;
  final bool canCaptureWindow;
  final bool shizukuActive;
  final bool adbActive;
  final NanoOperatingTier activeTier;

  const UniversalDeviceSnapshot({
    required this.manufacturer,
    required this.model,
    required this.sdkInt,
    required this.release,
    required this.cpuAbi,
    required this.ramTotalGb,
    required this.ramAvailableGb,
    required this.accessibilityActive,
    required this.canCaptureScreenshot,
    required this.canCaptureWindow,
    required this.shizukuActive,
    required this.adbActive,
    required this.activeTier,
  });
}

/// Detector universal y dinámico de capacidades de hardware y sistema Android.
///
/// Principios SOLID:
/// - SRP: Responsabilidad exclusiva de sondear el estado factual del dispositivo.
/// - DIP: Inyección de [SystemInventory] y [NanoRuntimeApi].
/// - Portabilidad: Agnóstico de fabricante (Samsung, Xiaomi, OPPO, Pixel, Motorola, etc.).
class UniversalCapabilityDetector {
  final SystemInventory? _inventory;
  final NanoRuntimeApi _runtime;

  UniversalCapabilityDetector({
    SystemInventory? inventory,
    NanoRuntimeApi? runtime,
  })  : _inventory = inventory,
        _runtime = runtime ?? NanoRuntimeApi.instance;

  /// Realiza un sondeo completo y factual del entorno Android.
  Future<UniversalDeviceSnapshot> detectCapabilities() async {
    // 1. Obtener perfil del dispositivo (fabricante, modelo, sdkInt)
    DeviceProfile? profile;
    try {
      if (_inventory != null) {
        profile = await _inventory.getDeviceProfile();
      }
    } catch (_) {
      profile = null;
    }

    final manufacturer = profile?.manufacturer ?? 'Android';
    final model = profile?.model ?? 'Universal Device';
    final sdkInt = profile?.sdkInt ?? 30;
    final release = profile?.release ?? 'Unknown';

    // 2. Telemetría de hardware (RAM y Arquitectura ABI)
    final metrics = await DeviceMetrics.fetch();
    final cpuAbi = _detectCpuAbi();

    // 3. Capacidades de visión y captura según nivel de API de Android
    // Android 11 (API 30+) soporta takeScreenshot() en AccessibilityService.
    // Android 14 (API 34+) soporta takeScreenshotOfWindow().
    final canCaptureScreenshot = sdkInt >= 30;
    final canCaptureWindow = sdkInt >= 34;

    // 4. Estado de servicios privilegiados (Accesibilidad, Shizuku, ADB)
    final accessibilityActive = await _checkAccessibilityActive();
    final shizukuActive = await _checkShizukuActive();
    final adbActive = await _checkAdbActive();

    // 5. Determinar el nivel operativo factual
    final activeTier = _resolveTier(
      shizukuActive: shizukuActive,
      adbActive: adbActive,
    );

    return UniversalDeviceSnapshot(
      manufacturer: manufacturer,
      model: model,
      sdkInt: sdkInt,
      release: release,
      cpuAbi: cpuAbi,
      ramTotalGb: metrics.ramTotalGb,
      ramAvailableGb: metrics.ramAvailableGb,
      accessibilityActive: accessibilityActive,
      canCaptureScreenshot: canCaptureScreenshot,
      canCaptureWindow: canCaptureWindow,
      shizukuActive: shizukuActive,
      adbActive: adbActive,
      activeTier: activeTier,
    );
  }

  Future<bool> _checkAccessibilityActive() async {
    try {
      final state = await _runtime.agentStatus();
      return state?['enabled'] == true || state?['connected'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkShizukuActive() async {
    try {
      final res = await _runtime.queryShizukuStatus();
      return res['running'] == true && res['authorized'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkAdbActive() async {
    try {
      // Comprobar si existe proceso de ADB local o puerto de depuración inalámbrica
      final env = Platform.environment;
      return env.containsKey('ADB_VENDOR_KEYS') || env.containsKey('ANDROID_ADB_SERVER_PORT');
    } catch (_) {
      return false;
    }
  }

  NanoOperatingTier _resolveTier({
    required bool shizukuActive,
    required bool adbActive,
  }) {
    if (shizukuActive) return NanoOperatingTier.advanced;
    if (adbActive) return NanoOperatingTier.developer;
    return NanoOperatingTier.normal;
  }

  String _detectCpuAbi() {
    final arch = Platform.version;
    if (arch.contains('arm64') || arch.contains('aarch64')) return 'arm64-v8a';
    if (arch.contains('arm')) return 'armeabi-v7a';
    if (arch.contains('x86_64')) return 'x86_64';
    return 'universal';
  }
}
