/// Soporte de test para el pipeline Candidate-First (A6).
///
/// Fakes que viven SOLO en tests. NO importar desde código de producción.
library;

import 'package:nanoai/features/automation/engine/system/capability_availability.dart';
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_graph.dart';
import 'package:nanoai/features/automation/engine/system/system_inventory.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart';

class FakeSystemInventory implements SystemInventory {
  FakeSystemInventory({required this.apps, this.launcher});

  final List<InstalledApp> apps;
  final String? launcher;
  int listCalls = 0;

  @override
  Future<DeviceProfile> getDeviceProfile() async => DeviceProfile(
    manufacturer: 'Test',
    model: 'Test',
    sdkInt: 34,
    release: '14',
    defaultLauncherPackage: launcher,
  );

  @override
  Future<List<InstalledApp>> listLaunchableApps() async {
    listCalls++;
    return apps;
  }

  @override
  Future<String?> getDefaultLauncher() async => launcher;
}

InstalledApp app(String label, String pkg) => InstalledApp(
  packageName: pkg,
  label: label,
  enabled: true,
  system: false,
  launchable: true,
);

InstalledAppCatalog catalogWith(List<InstalledApp> apps) =>
    InstalledAppCatalog(FakeSystemInventory(apps: apps));

/// SystemGraph con [capabilities] marcadas `available` (todo lo demás unknown).
SystemGraph graphWith(Set<SystemCapability> capabilities) => SystemGraph(
  device: const DeviceProfile(
    manufacturer: '',
    model: '',
    sdkInt: 0,
    release: '',
  ),
  apps: const [],
  roles: const [],
  capabilities: {
    for (final c in capabilities)
      c: CapabilityAvailability(
        capability: c,
        state: CapabilityAvailabilityKind.available,
        reason: 'test',
      ),
  },
);
