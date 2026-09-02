import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/system/capability_availability.dart';
import 'package:nanoai/features/automation/engine/system/capability_probes.dart';
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_destination.dart';
import 'package:nanoai/features/automation/engine/system/system_graph.dart';
import 'package:nanoai/features/automation/engine/system/system_intent_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_inventory.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart';
import 'package:nanoai/features/automation/engine/system/system_role.dart';

class FakeSystemInventory implements SystemInventory {
  FakeSystemInventory({required this.apps, this.launcher});

  final List<InstalledApp> apps;
  final String? launcher;
  int listCalls = 0;

  @override
  Future<DeviceProfile> getDeviceProfile() async => DeviceProfile(
    manufacturer: 'OPPO',
    model: 'CPH2557',
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

void main() {
  group('SystemGraph', () {
    test('compone DeviceProfile y resuelve rol launcher', () async {
      final inv = FakeSystemInventory(
        apps: [
          app('Chrome', 'com.android.chrome'),
          app('Launcher', 'com.oppo.launcher'),
        ],
        launcher: 'com.oppo.launcher',
      );
      final g = await SystemGraphBuilder(
        inventory: inv,
        catalog: InstalledAppCatalog(inv),
        probes: const [],
      ).build();

      expect(g.device.manufacturer, 'OPPO');
      expect(g.device.defaultLauncherPackage, 'com.oppo.launcher');
      final role = g.role(SystemRole.launcher);
      expect(role, isNotNull);
      expect(role!.app.packageName, 'com.oppo.launcher');
    });

    test('contiene apps launchable grounded', () async {
      final inv = FakeSystemInventory(
        apps: [app('Chrome', 'com.android.chrome')],
      );
      final g = await SystemGraphBuilder(
        inventory: inv,
        catalog: InstalledAppCatalog(inv),
        probes: const [],
      ).build();

      expect(g.apps, hasLength(1));
      expect(g.appByPackage('com.android.chrome'), isNotNull);
      final m = g.findApp('Chrome');
      expect(m, isA<AppMatchResolved>());
    });

    test('capability lookup y fallback unknown', () {
      const g = SystemGraph(
        device: DeviceProfile(
          manufacturer: '',
          model: '',
          sdkInt: 0,
          release: '',
        ),
        apps: [],
        roles: [],
        capabilities: {},
      );
      expect(
        g.availabilityOf(SystemCapability.launchApps).state,
        CapabilityAvailabilityKind.unknown,
      );
    });

    test('accessibility deshabilitada → requiresAccessibility', () async {
      final inv = FakeSystemInventory(apps: const []);
      final g = await SystemGraphBuilder(
        inventory: inv,
        catalog: InstalledAppCatalog(inv),
        probes: [
          AccessibilityCapabilityProbe(() async => false),
          NotificationCapabilityProbe(() async => false),
          LinuxCapabilityProbe(() => false),
          const SystemIntentCapabilityProbe(),
          const StaticSystemCapabilityProbe(),
        ],
      ).build();

      expect(
        g.availabilityOf(SystemCapability.globalHome).state,
        CapabilityAvailabilityKind.requiresAccessibility,
      );
      expect(
        g.availabilityOf(SystemCapability.observeAccessibility).state,
        CapabilityAvailabilityKind.requiresAccessibility,
      );
      expect(
        g.availabilityOf(SystemCapability.readNotifications).state,
        CapabilityAvailabilityKind.requiresNotificationAccess,
      );
      expect(
        g.availabilityOf(SystemCapability.openBluetoothSettings).state,
        CapabilityAvailabilityKind.available,
      );
      expect(
        g.availabilityOf(SystemCapability.shizuku).state,
        CapabilityAvailabilityKind.unsupported,
      );
    });

    test('accessibility activa → capabilities disponibles', () async {
      final inv = FakeSystemInventory(apps: const []);
      final g = await SystemGraphBuilder(
        inventory: inv,
        catalog: InstalledAppCatalog(inv),
        probes: [AccessibilityCapabilityProbe(() async => true)],
      ).build();

      expect(
        g.availabilityOf(SystemCapability.globalHome).state,
        CapabilityAvailabilityKind.available,
      );
      expect(
        g.availabilityOf(SystemCapability.interactAccessibility).state,
        CapabilityAvailabilityKind.available,
      );
    });

    test('refresh refleja estado cambiado', () async {
      final inv = FakeSystemInventory(apps: const []);
      var enabled = false;
      final builder = SystemGraphBuilder(
        inventory: inv,
        catalog: InstalledAppCatalog(inv),
        probes: [AccessibilityCapabilityProbe(() async => enabled)],
      );

      final before = await builder.build();
      expect(
        before.availabilityOf(SystemCapability.globalHome).state,
        CapabilityAvailabilityKind.requiresAccessibility,
      );

      enabled = true;
      final after = await builder.build();
      expect(
        after.availabilityOf(SystemCapability.globalHome).state,
        CapabilityAvailabilityKind.available,
      );
    });

    test('no muta el catálogo', () async {
      final inv = FakeSystemInventory(
        apps: [app('Chrome', 'com.android.chrome')],
      );
      final catalog = InstalledAppCatalog(inv);
      final g = await SystemGraphBuilder(
        inventory: inv,
        catalog: catalog,
        probes: const [],
      ).build();

      expect(g.apps, hasLength(1));
      g.findApp('Chrome');
      // El catálogo conserva su snapshot y no hubo nuevas llamadas al inventario.
      expect(inv.listCalls, 1);
      expect(await catalog.apps, hasLength(1));
    });
  });

  group('SystemDestination', () {
    test('allowlist contiene solo destinos A3', () {
      expect(SystemDestination.values, hasLength(3));
      expect(SystemDestination.values.map((d) => d.wireId), [
        'settings',
        'wifi_settings',
        'bluetooth_settings',
      ]);
    });

    test('raw unknown destination rechazado', () {
      expect(SystemDestination.fromWireId('bluetooth_settings'), isNotNull);
      expect(
        SystemDestination.fromWireId('android.settings.WIFI_SETTINGS'),
        isNull,
      );
      expect(SystemDestination.fromWireId('secret_action'), isNull);
    });
  });

  group('SystemIntentCatalog', () {
    test('solo navegación: no hay destino de cambio de estado', () {
      const catalog = SystemIntentCatalog.builtin;
      expect(catalog.isKnown(SystemDestination.bluetoothSettings), isTrue);
      for (final d in catalog.destinations) {
        expect(
          catalog.metaFor(d)!.kind,
          SystemIntentKind.navigation,
          reason: '${d.name} debe ser navegación, no state change',
        );
      }
    });
  });
}
