/// DIAG-01 — comandos internos de diagnóstico deterministas.
///
/// «@diag ping»: cadena local SIN LLM ni WhatsApp (entrada → engine →
/// coordinator → bridge nativo) — aísla si el fallo está antes del planner.
/// «@diag llm»: Dart → LLMEngineClient → motor local → respuesta, con
/// latencia. Ejecutan en la capa de entrada ANTES del planner y devuelven
/// [AutomationResult] para reusar el MISMO canal de resultado de la UI.
/// No tocan el pipeline de notificaciones ni WhatsApp.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/application/automation_engine_provider.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

const String diagPrefix = '@diag';

/// True si el texto es un comando de diagnóstico (debe interceptarse antes
/// del planner).
bool isDiagCommand(String text) =>
    text.trim().toLowerCase().startsWith('$diagPrefix ');

final automationDiagnosticsProvider =
    Provider<AutomationDiagnostics>((ref) => AutomationDiagnostics(ref));

class AutomationDiagnostics {
  AutomationDiagnostics(this._ref);

  final Ref _ref;

  /// Despacha el comando. Devuelve [AutomationResult] con la razón legible.
  Future<AutomationResult> run(String goal) async {
    final command = goal.trim().toLowerCase();
    final executionId = 'diag-${DateTime.now().millisecondsSinceEpoch}';
    try {
      if (command == '$diagPrefix ping') return await _ping(executionId);
      if (command == '$diagPrefix llm') return await _llm(executionId);
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: 'Comando diag desconocido: "$command". '
            'Uso: @diag ping o @diag llm',
      );
    } catch (e) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: 'diag lanzó excepción: $e',
      );
    }
  }

  /// Cadena local: input → engine → coordinator → bridge nativo. Cada eslabón
  /// se prueba con su acceso real; el primero que falla corta el informe.
  Future<AutomationResult> _ping(String executionId) async {
    final sw = Stopwatch()..start();
    final checks = <String>['input: PASS'];
    try {
      _ref.read(automationEngineProvider);
      checks.add('engine: PASS');
    } catch (e) {
      return _fail(executionId, sw, 'engine: FAIL ($e)');
    }
    try {
      _ref.read(automationCoordinatorProvider);
      checks.add('coordinator: PASS');
    } catch (e) {
      return _fail(executionId, sw, 'coordinator: FAIL ($e)');
    }
    try {
      // Llamada nativa REAL (no-op sin confirmación activa): prueba el
      // bridge Dart ↔ Kotlin, no solo la existencia del singleton.
      await NanoRuntimeApi.instance.dismissAutomationConfirmation();
      checks.add('native bridge: PASS');
    } catch (e) {
      return _fail(executionId, sw, 'native bridge: FAIL ($e)');
    }
    checks.add('latency: ${sw.elapsedMilliseconds} ms');
    return AutomationResult(
      executionId: executionId,
      status: AutomationResultStatus.completed,
      reason: 'DIAG PASS — ${checks.join(' | ')}',
    );
  }

  /// Ruta LLM completa: ensureReady (arranca el motor si cayó) + generación
  /// mínima. Vacío tras generar = patrón zombi conocido (revive con /reload).
  Future<AutomationResult> _llm(String executionId) async {
    final sw = Stopwatch()..start();
    final engine = _ref.read(runtimeEngineProvider.notifier);
    bool ready;
    try {
      ready = await engine.ensureReady();
    } catch (e) {
      return _fail(executionId, sw, 'motor no arrancó: $e');
    }
    if (!ready) {
      return _fail(executionId, sw, 'motor no quedó listo (ensureReady false)');
    }
    try {
      final result = await engine.client.generate(
        prompt: 'Responde exactamente: ok',
        maxTokens: 16,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        return _fail(
          executionId,
          sw,
          'motor respondió vacío (posible estado zombi — revive con /reload)',
        );
      }
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completed,
        reason: 'DIAG LLM PASS — respuesta="$text" '
            't=${sw.elapsedMilliseconds} ms',
      );
    } catch (e) {
      return _fail(executionId, sw, 'generación falló: $e');
    }
  }

  AutomationResult _fail(String executionId, Stopwatch sw, String reason) {
    return AutomationResult(
      executionId: executionId,
      status: AutomationResultStatus.failed,
      reason: 'DIAG FAIL ($reason) t=${sw.elapsedMilliseconds} ms',
    );
  }
}
