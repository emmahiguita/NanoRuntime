import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_result.dart';
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

Map<String, dynamic> _bluetoothSwitch(bool checked) => {
  'package': 'com.android.settings',
  'nodes': [
    {
      'id': 'com.android.settings:id/switch_widget',
      'type': 'android.widget.Switch',
      'text': 'Bluetooth',
      'desc': '',
      'clickable': true,
      'editable': false,
      'scrollable': false,
      'checked': checked,
      'focusable': true,
      'focused': false,
      'visible': true,
      'enabled': true,
      'bounds': [800, 200, 1040, 320],
      'depth': 2,
    },
  ],
};

class _FakeExecutor implements AgentExecutor {
  _FakeExecutor(this.raw);
  final Map<String, dynamic> raw;

  @override
  Future<NanoSnapshot?> snapshot() async => NanoSnapshot.fromRaw(raw);

  @override
  Future<ResolveOutcome> resolve(NanoSelector selector) async =>
      throw UnimplementedError();

  @override
  Future<AgentExecutionResult> setText(
    NanoSelector selector,
    String text,
  ) async => throw UnimplementedError();

  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async =>
      throw UnimplementedError();
}

void main() {
  const switchSelector = NanoSelector(text: 'Bluetooth', role: Role.switch_);

  test(
    'Bluetooth text visible is insufficient when checked state is false',
    () async {
      final verifier = GoalVerifier(
        executor: _FakeExecutor(_bluetoothSwitch(false)),
      );
      final result = await verifier.verify(
        'activar Bluetooth',
        planCompleted: true,
        expectation: const GoalExpectation(
          expectedPackage: 'com.android.settings',
          visibleText: 'Bluetooth',
          checkedSelector: switchSelector,
          expectedChecked: true,
        ),
      );
      expect(result.status, GoalStatus.notSatisfied);
    },
  );

  test('checked=true + package expected proves Bluetooth goal', () async {
    final verifier = GoalVerifier(
      executor: _FakeExecutor(_bluetoothSwitch(true)),
    );
    final result = await verifier.verify(
      'activar Bluetooth',
      planCompleted: true,
      expectation: const GoalExpectation(
        expectedPackage: 'com.android.settings',
        checkedSelector: switchSelector,
        expectedChecked: true,
      ),
    );
    expect(result.status, GoalStatus.satisfied);
  });
}
