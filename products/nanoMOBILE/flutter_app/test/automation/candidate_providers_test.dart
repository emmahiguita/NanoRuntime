import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/memory/experience_cache.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_provider.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_providers.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_intent_catalog.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;

import 'candidate_test_support.dart';

void main() {
  group('DeterministicCandidateProvider', () {
    test('"volver" → back grounded', () async {
      final p = DeterministicCandidateProvider(defaultDeterministicCatalog);
      final c = await p.provide(const CandidateRequest('volver'));
      expect(c, hasLength(1));
      expect(c.single.tool, 'back');
      expect(c.single.semanticAction, 'go_back');
      expect(c.single.channel, ActionChannel.deterministic);
      expect(
        c.single.evidence.single.source,
        ActionEvidenceSource.deterministicCatalog,
      );
    });

    test(
      '"abre Bluetooth" no lo emite (open_system → SystemIntentProvider)',
      () async {
        final p = DeterministicCandidateProvider(defaultDeterministicCatalog);
        expect(
          await p.provide(const CandidateRequest('abre Bluetooth')),
          isEmpty,
        );
      },
    );

    test(
      '"abre Chrome" no lo emite (launch_app → InstalledAppProvider)',
      () async {
        final p = DeterministicCandidateProvider(defaultDeterministicCatalog);
        expect(await p.provide(const CandidateRequest('abre Chrome')), isEmpty);
      },
    );
  });

  group('InstalledAppCandidateProvider', () {
    test('"abre Chrome" → launch_app grounded en PackageManager', () async {
      final p = InstalledAppCandidateProvider(
        catalogWith([app('Chrome', 'com.android.chrome')]),
      );
      final c = await p.provide(const CandidateRequest('abre Chrome'));
      expect(c, hasLength(1));
      expect(c.single.tool, 'launch_app');
      expect(c.single.args['packageName'], 'com.android.chrome');
      expect(
        c.single.evidence.single.source,
        ActionEvidenceSource.packageManager,
      );
      expect(
        c.single.requiredCapabilities,
        contains(SystemCapability.launchApps),
      );
      expect(c.single.expectation?.expectedPackage, 'com.android.chrome');
    });

    test('"abre com.fake.chrome" → sin candidato fabricado', () async {
      final p = InstalledAppCandidateProvider(
        catalogWith([app('Chrome', 'com.android.chrome')]),
      );
      expect(
        await p.provide(const CandidateRequest('abre com.fake.chrome')),
        isEmpty,
      );
    });

    test('"Whats" ambiguo → candidatos con menor confianza', () async {
      final p = InstalledAppCandidateProvider(
        catalogWith([
          app('WhatsApp', 'com.whatsapp'),
          app('WhatsApp Business', 'com.whatsapp.w4b'),
        ]),
      );
      final c = await p.provide(const CandidateRequest('abre Whats'));
      expect(c, hasLength(2));
      expect(c.every((x) => x.groundingConfidence == 0.5), isTrue);
    });
  });

  group('SystemIntentCandidateProvider', () {
    test('"abre Bluetooth" → open_system bluetooth_settings', () async {
      final p = SystemIntentCandidateProvider(
        defaultDeterministicCatalog,
        graphWith(const {SystemCapability.openBluetoothSettings}),
        SystemIntentCatalog.builtin,
      );
      final c = await p.provide(const CandidateRequest('abre Bluetooth'));
      expect(c, hasLength(1));
      expect(c.single.tool, 'open_system');
      expect(c.single.args['destination'], 'bluetooth_settings');
      expect(c.single.semanticAction, 'open_bluetooth_settings');
      expect(
        c.single.requiredCapabilities,
        contains(SystemCapability.openBluetoothSettings),
      );
    });

    test(
      '"activa Bluetooth" → sin candidato (state change no es navegación)',
      () async {
        final p = SystemIntentCandidateProvider(
          defaultDeterministicCatalog,
          graphWith(const {SystemCapability.openBluetoothSettings}),
          SystemIntentCatalog.builtin,
        );
        expect(
          await p.provide(const CandidateRequest('activa Bluetooth')),
          isEmpty,
        );
      },
    );

    test('capability no disponible → no emite candidato usable', () async {
      final p = SystemIntentCandidateProvider(
        defaultDeterministicCatalog,
        graphWith(const {}), // openBluetoothSettings no disponible
        SystemIntentCatalog.builtin,
      );
      expect(
        await p.provide(const CandidateRequest('abre Bluetooth')),
        isEmpty,
      );
    });
  });

  group('NanoFlowCandidateProvider', () {
    test('flow verificado de 1 paso → candidato nanoFlow', () async {
      final cache = ExperienceCache();
      cache.recordSuccess('abre Chrome', [
        const ToolCall(
          tool: 'launch_app',
          args: {'packageName': 'com.android.chrome'},
        ),
      ]);
      final p = NanoFlowCandidateProvider(cache);
      final c = await p.provide(const CandidateRequest('abre Chrome'));
      expect(c, hasLength(1));
      expect(c.single.channel, ActionChannel.nanoFlow);
      expect(c.single.tool, 'launch_app');
      expect(c.single.groundingConfidence, 1.0);
      expect(c.single.expectation?.expectedPackage, 'com.android.chrome');
    });

    test(
      'flow multi-step → sin candidato (es un flow, no una acción)',
      () async {
        final cache = ExperienceCache();
        cache.recordSuccess('multi', [
          const ToolCall(tool: 'tap', selector: 'x'),
          const ToolCall(tool: 'back'),
        ]);
        final p = NanoFlowCandidateProvider(cache);
        expect(await p.provide(const CandidateRequest('multi')), isEmpty);
      },
    );
  });
}
