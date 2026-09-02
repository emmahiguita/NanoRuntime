import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/system/app_graph.dart';
import 'package:nanoai/features/automation/engine/system/app_launch_resolver.dart';
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_inventory.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart';

/// Fake del inventario para tests (el fake vive en test; nunca en producción).
class FakeSystemInventory implements SystemInventory {
  FakeSystemInventory({
    required this.apps,
    this.profile = const DeviceProfile(
      manufacturer: 'Test',
      model: 'Test',
      sdkInt: 34,
      release: '14',
    ),
  });

  final List<InstalledApp> apps;
  final DeviceProfile profile;
  int listCalls = 0;

  @override
  Future<DeviceProfile> getDeviceProfile() async => profile;

  @override
  Future<List<InstalledApp>> listLaunchableApps() async {
    listCalls++;
    return apps;
  }

  @override
  Future<String?> getDefaultLauncher() async => profile.defaultLauncherPackage;
}

InstalledApp app({
  required String label,
  required String pkg,
  bool enabled = true,
  bool launchable = true,
  bool system = false,
}) => InstalledApp(
  packageName: pkg,
  label: label,
  versionName: '1.0',
  versionCode: 1,
  enabled: enabled,
  system: system,
  launchable: launchable,
);

void main() {
  group('InstalledApp parsing', () {
    test('fromMap parsea todos los campos factuales', () {
      final a = InstalledApp.fromMap({
        'packageName': 'com.android.chrome',
        'label': 'Chrome',
        'versionName': '126.0',
        'versionCode': 126000,
        'enabled': true,
        'systemApp': false,
        'launchable': true,
      });
      expect(a.packageName, 'com.android.chrome');
      expect(a.label, 'Chrome');
      expect(a.versionName, '126.0');
      expect(a.versionCode, 126000);
      expect(a.enabled, isTrue);
      expect(a.system, isFalse);
      expect(a.launchable, isTrue);
      expect(a.isLaunchCandidate, isTrue);
    });
  });

  group('InstalledAppCatalog.findApp', () {
    test('exact label match resuelve package real', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [
            app(label: 'Chrome', pkg: 'com.android.chrome'),
            app(label: 'WhatsApp', pkg: 'com.whatsapp'),
          ],
        ),
      );
      final r = await c.findApp('Chrome');
      expect(r, isA<AppMatchResolved>());
      expect((r as AppMatchResolved).app.packageName, 'com.android.chrome');
      expect(r.kind, AppMatchKind.exactLabel);
    });

    test('case-insensitive', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [app(label: 'Chrome', pkg: 'com.android.chrome')],
        ),
      );
      expect(await c.findApp('CHROME'), isA<AppMatchResolved>());
    });

    test('ambiguo no auto-selecciona', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [
            app(label: 'WhatsApp', pkg: 'com.whatsapp'),
            app(label: 'WhatsApp Business', pkg: 'com.whatsapp.w4b'),
          ],
        ),
      );
      final r = await c.findApp('Whats');
      expect(r, isA<AppMatchAmbiguous>());
      expect((r as AppMatchAmbiguous).candidates, hasLength(2));
    });

    test('unknown → notFound', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [app(label: 'Chrome', pkg: 'com.android.chrome')],
        ),
      );
      expect(await c.findApp('Spotify'), isA<AppMatchNotFound>());
    });

    test('exact package match (código determinista confiable)', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [app(label: 'Chrome', pkg: 'com.android.chrome')],
        ),
      );
      final r = await c.findApp('com.android.chrome');
      expect(r, isA<AppMatchResolved>());
      expect((r as AppMatchResolved).kind, AppMatchKind.exactPackage);
    });
  });

  group('InstalledAppCatalog refresh/dedup', () {
    test('refresh cachea y deduplica por package', () async {
      final inv = FakeSystemInventory(
        apps: [
          app(label: 'Chrome', pkg: 'com.android.chrome'),
          app(label: 'Chrome', pkg: 'com.android.chrome'),
        ],
      );
      final c = InstalledAppCatalog(inv);
      final apps = await c.refresh();
      expect(apps, hasLength(1));
      expect(inv.listCalls, 1);
      await c.apps; // servido del cache: sin nueva llamada al inventario
      expect(inv.listCalls, 1);
    });
  });

  group('AppLaunchResolver', () {
    test('"abre Chrome" resuelve package real del catálogo', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [app(label: 'Chrome', pkg: 'com.android.chrome')],
        ),
      );
      final plan = await AppLaunchResolver(c).resolve('abre Chrome');
      expect(plan, isNotNull);
      expect(plan!.call.tool, 'launch_app');
      expect(plan.call.args!['packageName'], 'com.android.chrome');
      expect(plan.expectation.expectedPackage, 'com.android.chrome');
    });

    test('package inventado no es posible (no resuelve)', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [app(label: 'Chrome', pkg: 'com.android.chrome')],
        ),
      );
      expect(
        await AppLaunchResolver(c).resolve('abre com.fake.chrome'),
        isNull,
      );
    });

    test('app disabled no es candidato de launch', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [
            app(label: 'Chrome', pkg: 'com.android.chrome', enabled: false),
          ],
        ),
      );
      expect(await AppLaunchResolver(c).resolve('abre Chrome'), isNull);
    });

    test('app no-launchable no es candidato', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [
            app(label: 'Chrome', pkg: 'com.android.chrome', launchable: false),
          ],
        ),
      );
      expect(await AppLaunchResolver(c).resolve('abre Chrome'), isNull);
    });

    test('ambiguo → null (no lanza)', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [
            app(label: 'WhatsApp', pkg: 'com.whatsapp'),
            app(label: 'WhatsApp Business', pkg: 'com.whatsapp.w4b'),
          ],
        ),
      );
      expect(await AppLaunchResolver(c).resolve('abre Whats'), isNull);
    });

    test('no es goal de apertura → null', () async {
      final c = InstalledAppCatalog(
        FakeSystemInventory(
          apps: [app(label: 'Chrome', pkg: 'com.android.chrome')],
        ),
      );
      expect(await AppLaunchResolver(c).resolve('activa bluetooth'), isNull);
    });
  });

  group('AppGraph foundation', () {
    test('capabilities factuales con proveniencia', () {
      final node = AppGraphNode.fromInstalledApp(
        app(label: 'Chrome', pkg: 'com.android.chrome', system: true),
      );
      expect(node.capabilities, contains(AppCapability.launch));
      expect(node.capabilities, contains(AppCapability.systemApp));
      expect(node.evidence[AppCapability.launch]!.source, 'launcherIntent');
      expect(
        node.evidence[AppCapability.systemApp]!.source,
        'applicationInfoFlags',
      );
    });
  });
}
