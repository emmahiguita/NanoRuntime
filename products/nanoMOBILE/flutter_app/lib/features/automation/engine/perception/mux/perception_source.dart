/// PerceptionSource / ScreenObserver (A8) — puertos de percepción.
///
/// Cada fuente devuelve un [PerceptionResult] tipado (no un selector string).
/// [ScreenObserver] es la frontera mínima de observación de pantalla (DIP):
/// el PerceptionMux no depende del AgentExecutor completo.
library;

import '../nano_snapshot.dart' show NanoSnapshot;
import 'perception_contracts.dart';
import 'perception_result.dart';

abstract interface class PerceptionSource {
  Future<PerceptionResult> perceive(
    PerceptionRequest request,
    PerceptionBudget budget,
  );
}

abstract interface class ScreenObserver {
  Future<NanoSnapshot?> snapshot();
}
