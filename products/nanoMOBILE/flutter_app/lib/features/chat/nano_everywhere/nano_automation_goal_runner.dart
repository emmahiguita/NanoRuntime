import '../../../core/services/owl_surface_bridge.dart';
import 'package:flutter/foundation.dart';
import '../../automation/application/automation_engine.dart';
import '../../automation/domain/automation_goal.dart';
import '../../automation/domain/automation_result.dart';
import '../../automation/engine/governance/action_confirmation.dart';
import '../../automation/engine/planning/whatsapp_component_requests.dart';
import '../../automation/ledger/automation_activity_store.dart';
import 'nano_action_input.dart';
import '../../automation/domain/prepared_automation_goal.dart';

/// Conecta el búho a la entrada pública del motor. El coordinador existente
/// posee percepción, planificación, políticas, journal y comprobación de pasos.
/// Esta clase conserva únicamente la ejecución propia y su confirmación exacta.
final class NanoAutomationGoalRunner {
  NanoAutomationGoalRunner(this.engine, {this.prepare});
  final AutomationEngine Function() engine;
  final Future<PreparedAutomationGoal> Function(
    String, {
    bool Function()? isCurrent,
  })?
  prepare;
  ({PreparedAutomationGoal prepared, ActionConfirmation token})? _pending;
  ({AutomationEngine engine, String id})? _active;

  /// Cancela la ejecución propia y descarta consentimiento pendiente. No reinicia
  /// el motor ni revierte acciones que ya pudieron tener efectos externos.
  void cancel() {
    _pending = null;
    final active = _active;
    if (active != null) active.engine.cancelExecution(active.id);
  }

  /// Un objetivo usa un único run. Reanudar conserva executionId y el token
  /// consumible del motor: no existe un «confirmed=true» que eluda su política.
  Future<String> run(String text, String id, bool Function() isCurrent) async {
    if (_active != null) return '[busy] Otra ejecución del búho sigue activa.';
    if (!isCurrent()) return '[cancelled] La tarea ya fue detenida.';
    final confirming = NanoActionInput.isConfirm(text);
    final pending = _pending;
    _pending = null;
    if (confirming &&
        (pending == null || pending.token.expired || pending.token.consumed)) {
      return '[clarification] No hay una acción pendiente vigente. '
          'Vuelve a escribir la instrucción; no se ejecutó nada.';
    }
    final confirmation = confirming ? pending!.token : null;
    final runId = confirmation?.executionId ?? id;
    final owner = engine();
    _active = (engine: owner, id: runId);
    _record(runId, 'call', 'Objetivo recibido por el coordinador compartido.');
    try {
      await OwlSurfaceBridge.hideForExecution(true);
      final prepared = confirming
          ? pending!.prepared
          : await prepare?.call(text, isCurrent: isCurrent) ??
                PreparedAutomationGoal(AutomationGoal(text: text));
      debugPrint('[owl-goal] prepared: ${prepared.plan == null ? 'dynamic' : 'explicit'}');
      if (!isCurrent()) {
        return '[cancelled] La tarea fue detenida durante su preparación.';
      }
      final goal = prepared.goal;
      var result = await owner.runGoal(
        goal,
        plan: prepared.plan,
        options: AutomationOptions(
          executionId: runId,
          confirmation: confirmation,
          isCurrent: isCurrent,
        ),
      );
      // La orden literal del usuario autoriza solo el paso del chat observado.
      // Se consume el token real del motor, sin elevar otros planes ni reintentar.
      final direct = !confirming &&
          (WhatsAppComponentRequests.currentChatDraft(text) != null ||
              WhatsAppComponentRequests.currentReply(text) != null);
      final step = prepared.plan;
      final directToken = result.confirmation;
      if (direct &&
          isCurrent() &&
          result.isPaused &&
          directToken != null &&
          !directToken.expired &&
          !directToken.consumed &&
          step != null &&
          step.length == 1 &&
          step.single.tool == 'whatsapp.send_message' &&
          step.single.args?['replyInPlace'] == true) {
        debugPrint('[owl-goal] resuming direct user action');
        result = await owner.runGoal(
          goal,
          plan: step,
          options: AutomationOptions(
            executionId: runId,
            confirmation: directToken,
            isCurrent: isCurrent,
          ),
        );
      }
      debugPrint('[owl-goal] result: ${result.status.name}');
      _record(runId, result.status.name, result.reason);
      if (!isCurrent()) {
        return '[cancelled] Detención solicitada; revisa cualquier efecto ya iniciado.';
      }
      final token = result.confirmation;
      if (result.isPaused &&
          token != null &&
          !token.expired &&
          !token.consumed) {
        _pending = (prepared: prepared, token: token);
        return '[paused] Se requiere tu confirmación.\n'
            'Objetivo: ${goal.text}\nPaso: ${token.stepId}\n'
            'Escribe «Confirmar acción» para autorizar únicamente este paso. '
            'Para descartarlo: «Cancelar acción». ${result.reason}';
      }
      return _describe(result);
    } on FormatException catch (error) {
      debugPrint('[owl-goal] preparation rejected');
      _record(runId, 'clarification', error.message);
      return '[clarification] ${error.message}';
    } catch (_) {
      debugPrint('[owl-goal] result unavailable');
      // No reintentar: un error de transporte no demuestra que nada ocurrió.
      _record(
        runId,
        'outcomeUnknown',
        'El motor no devolvió un resultado final.',
      );
      return '[outcomeUnknown] La ejecución no devolvió un resultado final. '
          'Comprueba el estado de la app antes de repetir.';
    } finally {
      _active = null;
      await OwlSurfaceBridge.hideForExecution(false);
    }
  }

  /// Conserva las categorías del dominio; terminar un plan sin prueba final
  /// no se presenta como objetivo cumplido ni entrega de un mensaje.
  String _describe(AutomationResult result) {
    final label = switch (result.status) {
      AutomationResultStatus.completed => 'Objetivo verificado por el motor.',
      AutomationResultStatus.completedUnverified =>
        'La ejecución terminó sin acreditar el objetivo completo.',
      AutomationResultStatus.paused =>
        'La acción está en pausa; no hay un token vigente para autorizarla aquí.',
      AutomationResultStatus.denied => 'La política bloqueó la acción.',
      AutomationResultStatus.noPlan =>
        'No hay un plan ejecutable para esta orden.',
      AutomationResultStatus.failed => 'No se pudo completar el objetivo.',
      AutomationResultStatus.outcomeUnknown =>
        'El resultado es incierto; no repitas la acción sin revisarla.',
      AutomationResultStatus.cancelled => 'Se solicitó detener la tarea.',
    };
    return '[${result.status.name}] $label\n${result.reason}';
  }

  /// Publica rutas reales en la bitácora SQLite existente; no guarda otro
  /// historial de chat ni el texto íntegro de la instrucción en este evento.
  void _record(String id, String state, String detail) {
    AutomationActivityStore.instance.record(
      runId: id,
      route: 'Búho → AutomationEngine → observación/acción/verificación',
      state: state,
      detail: detail,
    );
  }
}
