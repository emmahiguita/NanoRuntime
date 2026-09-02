/// SystemGraph (A3) — modelo factual, tipado y consultable del dispositivo.
///
/// NO es planner, ni executor, ni gestor de permisos, ni reemplazo de
/// Accessibility, ni dump de contexto del LLM. Es CONOCIMIENTO compuesto:
/// device + apps + roles + capabilities (con evidencia).
///
/// No ejecuta acciones. [SystemIntentLauncher] es el mecanismo, Policy la
/// autorización, Verifier la verdad final. A5/A6 (Candidate-First) preguntará
/// al grafo qué es posible y generará CandidateAction sin acoplar conocimiento
/// y ejecución.
library;

import 'capability_availability.dart';
import 'capability_probes.dart';
import 'installed_app_catalog.dart';
import 'system_capability.dart';
import 'system_inventory.dart';
import 'system_models.dart';
import 'system_role.dart';

/// Snapshot compuesto del modelo del dispositivo.
class SystemGraph {
  final DeviceProfile device;
  final List<InstalledApp> apps;
  final List<SystemRoleBinding> roles;
  final Map<SystemCapability, CapabilityAvailability> capabilities;

  const SystemGraph({
    required this.device,
    required this.apps,
    required this.roles,
    required this.capabilities,
  });

  CapabilityAvailability availabilityOf(SystemCapability capability) =>
      capabilities[capability] ?? CapabilityAvailability.unknown(capability);

  InstalledApp? appByPackage(String packageName) {
    for (final a in apps) {
      if (a.packageName == packageName) return a;
    }
    return null;
  }

  /// Resolución síncrona sobre el snapshot (sin tocar inventario ni cache).
  AppMatchResult findApp(String query) => matchApps(apps, query);

  SystemRoleBinding? role(SystemRole role) {
    for (final b in roles) {
      if (b.role == role) return b;
    }
    return null;
  }
}

/// Construye un [SystemGraph] leyendo facts + sondeando capabilities.
/// El AutomationCoordinator NO conoce cómo se recolectan los hechos.
class SystemGraphBuilder {
  SystemGraphBuilder({
    required SystemInventory inventory,
    required InstalledAppCatalog catalog,
    required List<CapabilityProbe> probes,
  }) : _inventory = inventory,
       _catalog = catalog,
       _probes = probes;

  final SystemInventory _inventory;
  final InstalledAppCatalog _catalog;
  final List<CapabilityProbe> _probes;

  Future<SystemGraph> build() async {
    final device = await _inventory.getDeviceProfile();
    final apps = await _catalog.apps;
    final capabilities = <SystemCapability, CapabilityAvailability>{};
    for (final probe in _probes) {
      capabilities.addAll(await probe.probe());
    }
    return SystemGraph(
      device: device,
      apps: apps,
      roles: _resolveRoles(device, apps),
      capabilities: capabilities,
    );
  }

  /// Solo asigna roles con evidencia: A3 resuelve únicamente `launcher` desde
  /// `DeviceProfile.defaultLauncherPackage`.
  List<SystemRoleBinding> _resolveRoles(
    DeviceProfile device,
    List<InstalledApp> apps,
  ) {
    final bindings = <SystemRoleBinding>[];
    final launcher = device.defaultLauncherPackage;
    if (launcher == null || launcher.isEmpty) return bindings;
    for (final a in apps) {
      if (a.packageName == launcher) {
        bindings.add(
          SystemRoleBinding(
            role: SystemRole.launcher,
            app: a,
            evidence: const SystemEvidence(
              SystemEvidenceSource.packageManager,
              'launcher',
            ),
          ),
        );
        break;
      }
    }
    return bindings;
  }
}
