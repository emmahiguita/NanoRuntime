/// Contexto reproducible del benchmark C14 (benchmark científico).
///
/// Permite comparar `commit X + Qwen 1.5B Q4 + 4 threads + ctx 4096` vs
/// `commit Y + ...` y saber que la diferencia viene del agente, no del runtime.
/// Los campos no disponibles se reportan como null/'' (nunca se inventan).
library;

import 'package:nanoai/core/config/app_boot_profile.dart';
import 'package:nanoai/core/config/app_build_info.dart';

class BenchmarkContext {
  final String gitCommit;
  final String appVersion;
  final String runtimeVersion;
  final String device;
  final String model;
  final String quant;
  final int? contextSize;
  final String backend;
  final int? threads;
  final double? temperature;
  final DateTime timestamp;

  /// Perfil de boot (normal | automationBenchmark) — reproduce el entorno.
  final String bootProfile;

  /// Estado del provisioning de NanoLinux en este run:
  /// 'skipped' (perfil benchmark) | 'boot' (provisionado en arranque).
  final String linuxProvisioning;

  /// Si C14-A requiere Linux (false: certifica planner→Android, no NanoLinux).
  final bool linuxRequired;

  const BenchmarkContext({
    required this.gitCommit,
    required this.appVersion,
    required this.runtimeVersion,
    required this.device,
    required this.model,
    this.quant = '',
    this.contextSize,
    this.backend = '',
    this.threads,
    this.temperature,
    required this.timestamp,
    required this.bootProfile,
    required this.linuxProvisioning,
    required this.linuxRequired,
  });

  factory BenchmarkContext.capture({
    String runtimeVersion = '',
    String device = '',
    String model = '',
    String quant = '',
    int? contextSize,
    String backend = '',
    int? threads,
    double? temperature,
  }) {
    final profile = AppBootProfile.current;
    final linuxSkipped = profile.skipsLinuxProvisioning;
    return BenchmarkContext(
      gitCommit: AppBuildInfo.gitCommit,
      appVersion: AppBuildInfo.appVersion,
      runtimeVersion: runtimeVersion,
      device: device.isEmpty ? AppBuildInfo.deviceModel : device,
      model: model,
      quant: quant,
      contextSize: contextSize,
      backend: backend,
      threads: threads,
      temperature: temperature,
      timestamp: DateTime.now(),
      bootProfile: profile.name,
      linuxProvisioning: linuxSkipped ? 'skipped' : 'boot',
      linuxRequired: !linuxSkipped,
    );
  }

  Map<String, dynamic> toJson() => {
    'gitCommit': gitCommit,
    'appVersion': appVersion,
    'runtimeVersion': runtimeVersion,
    'device': device,
    'model': model,
    'quant': quant,
    'contextSize': contextSize,
    'backend': backend,
    'threads': threads,
    'temperature': temperature,
    'timestamp': timestamp.toIso8601String(),
    'bootProfile': bootProfile,
    'linuxProvisioning': linuxProvisioning,
    'linuxRequired': linuxRequired,
  };
}
