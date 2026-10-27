/// AUTOMATION-ENGINE-STATUS-PROVIDER — Estado factual del motor de IA.
///
/// QUÉ HACE:
/// Provee el estado en tiempo real del runtime local (puerto 8080).
///
/// CÓMO FUNCIONA:
/// Consulta directamente el endpoint HTTP real vía [isOnline] y [hasModel].
///
/// POR QUÉ:
/// Refleja la realidad técnica sin simular ni mentir sobre la disponibilidad del LLM.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/runtime_engine.dart';

final engineStatusProvider = FutureProvider<EngineStatus?>((ref) async {
  final state = ref.watch(runtimeEngineProvider);
  // Un motor idle no tiene servidor HTTP que consultar. El sondeo anterior
  // hacía cinco intentos al puerto local en cada arranque del panel y añadía
  // latencia/CPU aunque el modelo estuviera correctamente dormido.
  if (!state.isLive) return state;
  try {
    final client = ref.read(runtimeEngineProvider.notifier).client;
    final online = await client.isOnline(
      attempts: 1,
      requestTimeout: const Duration(seconds: 2),
    );
    final hasModel = online && await client.hasModel();
    if (online && hasModel) {
      return EngineStatus(
        port: state.port,
        phase: EnginePhase.ready,
        modelPath: state.modelPath ?? 'modelo-cargado',
      );
    }
  } catch (_) {
    // endpoint no responde → usar el estado del notifier (honesto).
  }
  return state;
});
