import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('selectModel EXTREME requiere confirmación explícita (Gate R9)', () {
    final container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(
          (ref) => ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier);

    final extreme = NeuralCatalog.models.firstWhere(
      (m) => m.tier == ModelTier.extreme,
    );
    final interactive = NeuralCatalog.models.firstWhere(
      (m) => m.tier == ModelTier.interactive,
    );

    // EXTREME sin confirmación → NO aplica (defensa en profundidad).
    notifier.selectModel(extreme.name);
    expect(
      notifier.state.activeModel,
      isNot(extreme.name),
      reason: 'extreme sin confirmación no debe seleccionarse',
    );

    // EXTREME con confirmación explícita → aplica.
    notifier.selectModel(extreme.name, confirmedExtreme: true);
    expect(notifier.state.activeModel, extreme.name);

    // INTERACTIVE sin confirmación → aplica directo.
    notifier.selectModel(interactive.name);
    expect(notifier.state.activeModel, interactive.name);
  });

  test('NeuralCatalog.defaultInteractive nunca es DEEP/EXTREME (Gate R9)', () {
    final def = NeuralCatalog.defaultInteractive;
    expect(def.tier, ModelTier.interactive);
  });

  test('selectModel rota la sesión al cambiar de modelo (Gate R5)', () {
    final container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(
          (ref) => ChatNotifier.fixed(ref, const ChatState(engineOnline: true)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier);

    final first = NeuralCatalog.models.firstWhere(
      (m) => m.tier == ModelTier.interactive,
    );
    final second = NeuralCatalog.models[1]; // otro modelo interactive

    final sid1 = notifier.sessionId;

    // Default ('Sin modelo') → first: cambia de modelo, rota sesión.
    notifier.selectModel(first.name);
    final sid2 = notifier.sessionId;
    expect(sid2, isNot(sid1));

    // Mismo modelo de nuevo → NO rota.
    notifier.selectModel(first.name);
    expect(notifier.sessionId, sid2);

    // Otro modelo → rota.
    notifier.selectModel(second.name);
    expect(notifier.sessionId, isNot(sid2));
  });
}
