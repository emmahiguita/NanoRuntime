import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/capability_router.dart';
import 'package:nanoai/features/automation/engine/memory/nano_transcript_ledger.dart';

void main() {
  group('NanoTranscriptLedger (Multisuperficie y Poda de Logs)', () {
    late NanoTranscriptLedger ledger;

    setUp(() {
      ledger = NanoTranscriptLedger(maxOperativeWindow: 2);
    });

    test('recordLinuxStep: registra paso de superficie Linux sin snapshot visual', () {
      final step = ledger.recordLinuxStep(
        actionName: 'nano.linux.git.status',
        commandDescription: 'git status --short',
        executionOk: true,
        verificationOk: true,
        summary: 'branch=master clean=true',
        metadata: {'fullLog': 'A massive log with 50,000 characters...'},
      );

      expect(step.surface, equals(AutomationSurface.linux));
      expect(step.packageName, equals('nano.linux'));
      expect(step.succeeded, isTrue);
      expect(step.snapshot, isNull);
      expect(step.isPruned, isTrue);
      expect(step.toSummaryMap()['surface'], equals('linux'));
    });

    test('Poda de contexto: el contextSummary contiene solo el resumen hito', () {
      ledger.recordLinuxStep(
        actionName: 'nano.linux.git.status',
        commandDescription: 'git status',
        executionOk: true,
        verificationOk: true,
        summary: 'branch=master dirty=false',
      );

      ledger.recordLinuxStep(
        actionName: 'nano.linux.gradle.test',
        commandDescription: './gradlew test',
        executionOk: true,
        verificationOk: true,
        summary: 'tests=148 failed=0 duration=12s',
        metadata: {'rawStdout': 'Thousands of lines of compiler logs...'},
      );

      final summary = ledger.buildContextSummary();

      expect(summary, contains('[✓] Paso 1 (nano.linux.git.status): branch=master dirty=false'));
      expect(summary, contains('[✓] Paso 2 (nano.linux.gradle.test): tests=148 failed=0 duration=12s'));
      // No contiene los miles de líneas del log
      expect(summary.contains('Thousands of lines'), isFalse);
    });

    test('Flujo híbrido Linux + Mobile: conviven armónicamente en el ledger', () {
      ledger.recordLinuxStep(
        actionName: 'nano.linux.archive.create',
        commandDescription: 'tar -czf /tmp/backup.tar.gz /data',
        executionOk: true,
        verificationOk: true,
        summary: 'backup.tar.gz creado (4.2MB)',
      );

      ledger.recordStep(
        actionName: 'tap',
        actionDescription: 'Tocar botón Enviar',
        executionOk: true,
        verificationOk: true,
        observedOutcome: 'Mensaje enviado',
      );

      expect(ledger.totalSteps, equals(2));
      expect(ledger.allSteps[0].surface, equals(AutomationSurface.linux));
      expect(ledger.allSteps[1].surface, equals(AutomationSurface.androidAccessibility));
    });
  });
}
