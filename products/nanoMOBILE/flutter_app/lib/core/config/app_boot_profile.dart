/// Perfil de arranque de la app — desacopla el provisioning de NanoLinux del
/// boot normal.
///
/// Principio arquitectónico: NanoRuntime y NanoAutomation deben poder arrancar
/// AUNQUE NanoLinux no esté disponible. Linux se provisiona on-demand cuando
/// una ruta de automatización realmente lo necesita; un fallo de
/// `ffmpeg/git/python/rootfs` NO debe impedir que la app quede operativa.
///
/// Inyectado en build-time:
///   --dart-define=NANO_BOOT_PROFILE=automation-benchmark
library;

enum AppBootProfile {
  /// Boot completo: provisiona NanoLinux (rootfs + paquetes + desktop) tras el
  /// primer frame. Si falla, la app sigue operativa (UI/runtime/automation).
  normal,

  /// Perfil del benchmark C14-A: SOLO UI + runtime + automation + accesibilidad.
  /// EL PROVISIONING DE NANOLINUX SE OMITE (no lo ejercita C14-A). El preflight
  /// lo registra como `skipped` (honesto), nunca como READY.
  automationBenchmark;

  static const _fromEnv = String.fromEnvironment('NANO_BOOT_PROFILE');

  static AppBootProfile get current =>
      _fromEnv == 'automation-benchmark' ? automationBenchmark : normal;

  /// Linux no se provisiona en el arranque en este perfil.
  bool get skipsLinuxProvisioning => this == automationBenchmark;
}
