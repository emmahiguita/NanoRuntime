import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/linux_execution_backend.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/orchestration/automation_run.dart';
import 'package:nanoai/features/automation/engine/orchestration/execution_journal.dart';
import 'package:nanoai/features/automation/engine/platform/linux_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingLinuxExecutionBackend implements LinuxExecutionBackend {
  final List<LinuxExecutionRequest> requests = [];

  @override
  Future<LinuxExecutionResult> execute(LinuxExecutionRequest request) async {
    requests.add(request);
    return const LinuxExecutionResult(
      exitCode: 0,
      stdout: 'ok',
      stderr: '',
      duration: Duration.zero,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hardening Phase 4 - Linux Dynamic Timeout Clamping', () {
    test('linux.readFile ignores dynamic timeout expansion above def.timeout', () async {
      final backend = _CapturingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);
      final dispatcher = AgentToolDispatcher(
        linuxAdapter: adapter,
        executionJournal: InMemoryExecutionJournal(),
      );

      const jsonStr = '{"tool": "linux.readFile", "path": "/tmp/test.txt", "timeout": 120000}';
      final call = AgentToolProtocol.extractToolCall(jsonStr)!;

      final result = await dispatcher.runTool(call);
      expect(result, isNot(contains('[tool]')));
      expect(backend.requests, hasLength(1));
      // Must clamp to default definition timeout (15s) rather than 120s
      expect(backend.requests.single.timeout, const Duration(milliseconds: 15000));
    });

    test('linux.run allows dynamic timeout expansion up to 600s', () async {
      final backend = _CapturingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);
      final dispatcher = AgentToolDispatcher(
        linuxAdapter: adapter,
        executionJournal: InMemoryExecutionJournal(),
      );

      const jsonStr = '{"tool": "linux.run", "command": "ls -la", "timeout": 120000}';
      final call = AgentToolProtocol.extractToolCall(jsonStr)!;

      final outcome = await dispatcher.runToolGuarded(call, confirmed: true);
      expect(outcome.verdict, PolicyVerdict.allow);
      expect(backend.requests, hasLength(1));
      expect(backend.requests.single.timeout, const Duration(milliseconds: 120000));
    });

    test('linux.run clamps dynamic timeout expansion at 600s ceiling', () async {
      final backend = _CapturingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);
      final dispatcher = AgentToolDispatcher(
        linuxAdapter: adapter,
        executionJournal: InMemoryExecutionJournal(),
      );

      const jsonStr = '{"tool": "linux.run", "command": "ls -la", "timeout": 999999}';
      final call = AgentToolProtocol.extractToolCall(jsonStr)!;

      final outcome = await dispatcher.runToolGuarded(call, confirmed: true);
      expect(outcome.verdict, PolicyVerdict.allow);
      expect(backend.requests, hasLength(1));
      expect(backend.requests.single.timeout, const Duration(milliseconds: 600000));
    });
  });

  group('Hardening Phase 4 - AutomationRun Physical Effect Truth', () {
    test('marks physical effect dispatched on enterStep and explicitly', () {
      final run = AutomationRun(
        executionId: 'run-1',
        goal: 'test goal',
      );

      expect(run.hasDispatchedPhysicalEffect, isFalse);

      run.beginPlanning();
      expect(run.hasDispatchedPhysicalEffect, isFalse);

      run.enterStep(0);
      expect(run.hasDispatchedPhysicalEffect, isTrue);
    });
  });

  group('Hardening Phase 4 - SharedPrefsRuleStore Admission Mirror', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('reconciles eligible_packages on load if mirror missing or out of sync', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsRuleStore();

      final rule = ScheduledRule(
        id: 'r_wa',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        createdAt: DateTime(2026, 8, 27),
      );

      // Save properly through store to ensure valid JSON format
      await store.save([rule]);
      expect(prefs.getString('automation.eligible_packages'), 'com.whatsapp');

      // Tamper mirror to simulate missing or stale state
      await prefs.setString('automation.eligible_packages', 'stale.package');

      // Load must reconcile and repair the mirror
      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(prefs.getString('automation.eligible_packages'), 'com.whatsapp');
    });
  });
}
