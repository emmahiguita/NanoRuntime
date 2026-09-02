/// SystemRole (A3) — rol factual de una app en el sistema.
///
/// Solo se asigna un rol cuando hay evidencia. A3 resuelve únicamente
/// `launcher` (de `DeviceProfile.defaultLauncherPackage`, A2). Los demás roles
/// quedan sin binding (sin heurística OEM prematura). No se infiere "Chrome
/// existe → Chrome es navegador por defecto".
library;

import 'system_capability.dart';
import 'system_models.dart';

enum SystemRole {
  launcher,
  settings,
  systemUi,
  permissionController,
  packageInstaller,
  browser,
}

/// Vincula un [SystemRole] a una app concreta con evidencia.
class SystemRoleBinding {
  final SystemRole role;
  final InstalledApp app;
  final SystemEvidence evidence;

  const SystemRoleBinding({
    required this.role,
    required this.app,
    required this.evidence,
  });
}
