import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/providers/settings_provider.dart';

class _FailingSettingsRepo extends SettingsRepository {
  bool failSave = true;

  @override
  Future<void> save(SettingsState s) async {
    if (failSave) {
      throw StateError('Simulated SharedPreferences disk failure');
    }
  }

  @override
  Future<SettingsState> load() async {
    return const SettingsState();
  }
}

void main() {
  test('SettingsNotifier rolls back to previous state when disk save fails', () async {
    final repo = _FailingSettingsRepo();
    final notifier = SettingsNotifier(repo);

    // Initial state
    expect(notifier.state.waAutonomyMode, isNull);

    // Attempt to change autonomy to 'disabled' while disk fails
    repo.failSave = true;
    try {
      notifier.setWaAutonomyMode('disabled');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } catch (_) {}

    // Invariant: UI/RAM state must NOT claim 'disabled' if disk rejected it!
    expect(notifier.state.waAutonomyMode, isNull);

    // When save succeeds, state updates normally
    repo.failSave = false;
    notifier.setWaAutonomyMode('disabled');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(notifier.state.waAutonomyMode, 'disabled');
  });
}
