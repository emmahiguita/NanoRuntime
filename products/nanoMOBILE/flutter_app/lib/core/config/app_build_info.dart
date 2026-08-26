/// Info de build reproducible, inyectada en build-time (no en runtime).
///
/// -D GIT_COMMIT=<sha>  permite comparar commits/models: saber que una
/// diferencia de benchmark viene del agente y no del runtime.
/// -D APP_VERSION=<x.y.z>
library;

class AppBuildInfo {
  static const String gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'unknown',
  );
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.0.0',
  );

  /// Modelo de dispositivo físico (reproducibilidad del benchmark C14).
  static const String deviceModel = String.fromEnvironment(
    'DEVICE_MODEL',
    defaultValue: 'unknown',
  );
}
