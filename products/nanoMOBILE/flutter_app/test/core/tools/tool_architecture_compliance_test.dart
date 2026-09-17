import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Formal tool architecture compliance', () {
    test('core/tools never depends on feature implementations', () {
      final files = Directory('lib/core/tools')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('package:nanoai/features/')),
          reason: '${file.path} must remain feature-agnostic',
        );
      }
    });

    test('skills do not import Android/runtime infrastructure directly', () {
      final files = Directory('lib/features/skills')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('MethodChannel')), reason: file.path);
        expect(
          source,
          isNot(contains('nano_runtime_api.dart')),
          reason: file.path,
        );
        expect(source, isNot(contains('/android/')), reason: file.path);
        expect(
          source,
          contains('ToolRouter'),
          reason: '${file.path} must orchestrate through ToolRouter',
        );
      }
    });

    test('actions do not invoke other actions directly', () {
      final files = Directory('lib/features/actions')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('package:nanoai/features/actions/')),
          reason: '${file.path} must not call another Action',
        );
      }
    });

    test(
      'production composition root bootstraps and freezes formal registry',
      () {
        final source = File(
          'lib/features/automation/application/automation_coordinator_provider.dart',
        ).readAsStringSync();
        expect(source, contains('formalToolRouterProvider'));
        expect(source, contains('registry.freeze()'));
        expect(source, contains('ToolRoutedConversationReplyComposer'));
        expect(source, contains('SharedPreferencesToolAuditTrail'));
      },
    );

    test('production registry constructs with every required capability', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(formalToolRouterProvider);

      expect(router.registry.isFrozen, isTrue);
      expect(
        router.registry.list().map((tool) => tool.definition.id),
        containsAll(<String>{
          'conversation.classify',
          'conversation.composePersonal',
          'personal.getStyle',
          'personal.findExamples',
          'whatsapp.reply',
          'respondPersonalWhatsApp',
        }),
      );
    });
  });
}
