import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';

void main() {
  group('Automation Architecture & SOLID Compliance', () {
    test('STRICT RULE: Ningún archivo en lib/features/automation supera las 900 líneas', () {
      final dir = Directory('lib/features/automation');
      expect(dir.existsSync(), isTrue, reason: 'El directorio lib/features/automation debe existir');

      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(dartFiles.isNotEmpty, isTrue);

      final oversizedFiles = <String, int>{};
      for (final file in dartFiles) {
        final lineCount = file.readAsLinesSync().length;
        if (lineCount > 900) {
          oversizedFiles[file.path] = lineCount;
        }
      }

      expect(
        oversizedFiles,
        isEmpty,
        reason: 'Archivos que violan la regla estricta de < 900 líneas: $oversizedFiles',
      );
    });

    test('AutomationCoordinator modularizado respeta Single Responsibility y Clean Architecture', () {
      final coordinatorFile = File('lib/features/automation/application/automation_coordinator.dart');
      final lines = coordinatorFile.readAsLinesSync().length;
      expect(lines, lessThan(900), reason: 'AutomationCoordinator debe tener menos de 900 líneas');

      final executionFile = File('lib/features/automation/application/automation_coordinator_execution.dart');
      expect(executionFile.existsSync(), isTrue);
      expect(executionFile.readAsLinesSync().length, lessThan(900));

      final resultsFile = File('lib/features/automation/application/automation_coordinator_results.dart');
      expect(resultsFile.existsSync(), isTrue);
      expect(resultsFile.readAsLinesSync().length, lessThan(900));
    });

    test('AutomationCoordinator instanciación básica y tipado', () {
      final coordinator = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.assisted,
      );
      expect(coordinator, isNotNull);
    });
  });
}
