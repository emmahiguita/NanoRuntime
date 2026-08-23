/// NanoAgentExecutor — ejecución segura de acciones UI sobre el canal
/// `com.nanoai/agent`.
///
/// Invariantes (filosofía Playwright):
/// 1. NUNCA gesto sin resolve — snapshot fresco antes de cada acción.
/// 2. Ambigüedad o notFound abortan con [AgentErrorCode] tipado.
/// 3. Antes del gesto: actionability + espera de settle + re-resolución con
///    [StabilityChecker] (el UI pudo moverse — rebind ColorOS, animaciones).
/// 4. Gestos solo por coordenadas del CENTRO del bounds del nodo resuelto
///    ([NanoRuntimeApi.agentTapAt]) — jamás el método legacy agentTapOnText
///    (primer nodo con contains, sin unicidad).
/// 5. El canal puede morir (cached-kill ColorOS): [snapshot] reintenta
///    3 × 250ms y degrada a error tipado, nunca excepción.
library;

import '../../../core/services/nano_runtime_api.dart';
import 'actionability_engine.dart';
import 'agent_result.dart';
import 'nano_selector.dart';
import 'nano_snapshot.dart';
import 'selector_engine.dart';

/// Contrato mínimo del ejecutor (DIP): lo que [AgentLoop] necesita.
/// [NanoAgentExecutor] lo implementa; los tests usan fakes.
abstract interface class AgentExecutor {
  Future<NanoSnapshot?> snapshot();

  /// RESOLVE del ciclo OBSERVE→RESOLVE→ACT→VERIFY: resuelve [selector]
  /// contra el snapshot fresco con [ResolveOutcome] tipado.
  Future<ResolveOutcome> resolve(NanoSelector selector);

  Future<AgentExecutionResult> tap(NanoSelector selector);
  Future<AgentExecutionResult> setText(NanoSelector selector, String text);
}

/// Ejecutor de alto nivel. Puro en su lógica (motores inyectables) — el único
/// punto de contacto con el canal es [NanoRuntimeApi].
class NanoAgentExecutor implements AgentExecutor {
  NanoAgentExecutor({
    NanoRuntimeApi? api,
    NanoSelectorEngine? engine,
    StabilityChecker? stability,
  })  : _api = api ?? NanoRuntimeApi.instance,
        _engine = engine ?? NanoSelectorEngine(),
        _stability = stability ?? const StabilityChecker();

  final NanoRuntimeApi _api;
  final NanoSelectorEngine _engine;
  final StabilityChecker _stability;

  /// Intentos de snapshot antes de rendirse (rebind ColorOS ~100-500ms).
  int get snapshotMaxAttempts => 3;

  Duration get snapshotRetryDelay => const Duration(milliseconds: 250);

  // ── Snapshot ──────────────────────────────────────────────────────────────

  /// Snapshot con retry de rebind. null = canal muerto (servicio off o error
  /// de plataforma); snapshot con [NanoSnapshot.isEmpty] = canal vivo pero
  /// sin ventana activa (rebind largo).
  @override
  Future<NanoSnapshot?> snapshot() async {
    Map<dynamic, dynamic>? lastRaw;
    for (var attempt = 1; attempt <= snapshotMaxAttempts; attempt++) {
      lastRaw = await _api.agentDumpSnapshot();
      if (lastRaw != null) {
        final snap = NanoSnapshot.fromRaw(lastRaw);
        if (!snap.isEmpty) return snap;
      }
      if (attempt < snapshotMaxAttempts) {
        await Future<void>.delayed(snapshotRetryDelay);
      }
    }
    return lastRaw != null ? NanoSnapshot.fromRaw(lastRaw) : null;
  }

  /// Resuelve sin ejecutar nada — el reporte de la consola en Settings.
  /// Resuelve [selector] contra el snapshot fresco (RESOLVE del ciclo).
  @override
  Future<ResolveOutcome> resolve(NanoSelector selector) async {
    final snap = await snapshot();
    if (snap == null) {
      return ResolveOutcome(
        status: ResolveStatus.serviceOff,
        candidates: const [],
        reason: 'Accesibilidad apagada o canal sin respuesta '
            '($snapshotMaxAttempts reintentos).',
      );
    }
    if (snap.isEmpty) {
      return const ResolveOutcome(
        status: ResolveStatus.serviceOff,
        candidates: [],
        reason: 'Sin ventana activa: snapshot vacío (rebind ColorOS en '
            'curso).',
      );
    }
    return _engine.resolve(selector, snap);
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  /// Tap seguro sobre [selector]: snapshot → resolve → actionability →
  /// estabilidad → tapAt(centro del bounds).
  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async {
    final snap = await snapshot();
    if (snap == null) {
      return const AgentExecutionResult.failure(
        errorCode: AgentErrorCode.serviceOff,
        reason: 'Accesibilidad apagada o canal sin respuesta.',
      );
    }
    if (snap.isEmpty) {
      return const AgentExecutionResult.failure(
        errorCode: AgentErrorCode.snapshotEmpty,
        reason: 'Snapshot vacío: sin ventana activa (rebind en curso).',
      );
    }

    final resolve = _engine.resolve(selector, snap);
    if (!resolve.isResolved) return _statusFailure(resolve);

    final best = resolve.best!;
    final actionability = ActionabilityState.check(
      kind: ActionKind.tap,
      node: best.node,
      unique: true,
      snapshotPackage: snap.package,
      expectedPackage: selector.packageName,
    );
    if (!actionability.actionable) {
      return AgentExecutionResult.failure(
        errorCode: AgentErrorCode.notActionable,
        reason: actionability.failureReason!,
        resolve: resolve,
        actionability: actionability,
      );
    }

    // Settle + re-resolución: el nodo debe seguir donde estaba.
    final stableNode = await _waitStable(selector, best.node);
    if (stableNode == null) {
      return AgentExecutionResult.failure(
        errorCode: AgentErrorCode.unstableTarget,
        reason: 'Objetivo inestable: se movió durante la espera de settle '
            '(${_stability.maxCenterDeltaPx}px / '
            '${_stability.maxSizeChangeRatio * 100}%).',
        resolve: resolve,
        actionability: actionability,
      );
    }

    final ok = await _api.agentTapAt(
      stableNode.bounds.centerX.round(),
      stableNode.bounds.centerY.round(),
    );
    if (!ok) {
      return AgentExecutionResult.failure(
        errorCode: AgentErrorCode.gestureFailed,
        reason: 'El gesto tapAt(${stableNode.bounds.centerX.round()}, '
            '${stableNode.bounds.centerY.round()}) falló en el canal.',
        resolve: resolve,
        actionability: actionability,
      );
    }
    return AgentExecutionResult.ok(
      resolve: resolve,
      actionability: actionability,
      targetNode: stableNode,
    );
  }

  /// Escribe [text] en el campo de [selector]. Si el campo no tiene foco,
  /// primero hace [tap] (foco verificado contra re-snapshot — si sigue sin
  /// foco, aborta con notActionable).
  @override
  Future<AgentExecutionResult> setText(
    NanoSelector selector,
    String text,
  ) async {
    final snap = await snapshot();
    if (snap == null) {
      return const AgentExecutionResult.failure(
        errorCode: AgentErrorCode.serviceOff,
        reason: 'Accesibilidad apagada o canal sin respuesta.',
      );
    }
    if (snap.isEmpty) {
      return const AgentExecutionResult.failure(
        errorCode: AgentErrorCode.snapshotEmpty,
        reason: 'Snapshot vacío: sin ventana activa (rebind en curso).',
      );
    }

    var resolve = _engine.resolve(selector, snap);
    if (!resolve.isResolved) return _statusFailure(resolve);

    var node = resolve.best!.node;
    if (!node.focused) {
      // Enfocar con tap seguro (misma garantía que tap()).
      final focusTap = await tap(selector);
      if (!focusTap.ok) return focusTap;
      final snap2 = await snapshot();
      if (snap2 == null) {
        return AgentExecutionResult.failure(
          errorCode: AgentErrorCode.serviceOff,
          reason: 'Canal murió tras el tap de foco.',
          resolve: resolve,
        );
      }
      final re = _engine.resolve(selector, snap2);
      if (!re.isResolved) return _statusFailure(re);
      node = re.best!.node;
      if (!node.focused) {
        return AgentExecutionResult.failure(
          errorCode: AgentErrorCode.notActionable,
          reason: 'Campo no enfocable: tras tap de foco sigue sin foco.',
          resolve: re,
        );
      }
      resolve = re;
    }

    final actionability = ActionabilityState.check(
      kind: ActionKind.input,
      node: node,
      unique: true,
      snapshotPackage: snap.package,
      expectedPackage: selector.packageName,
    );
    if (!actionability.actionable) {
      return AgentExecutionResult.failure(
        errorCode: AgentErrorCode.notActionable,
        reason: actionability.failureReason!,
        resolve: resolve,
        actionability: actionability,
      );
    }

    final ok = await _api.agentInputText(text);
    if (!ok) {
      return AgentExecutionResult.failure(
        errorCode: AgentErrorCode.inputFailed,
        reason: 'El canal rechazó inputText("$text").',
        resolve: resolve,
        actionability: actionability,
      );
    }
    return AgentExecutionResult.ok(
      resolve: resolve,
      actionability: actionability,
      targetNode: node,
    );
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  /// Re-resuelve [selector] tras [_stability.wait] y devuelve el nodo
  /// re-resuelto solo si es estable (1 reintento extra).
  Future<NanoNode?> _waitStable(
    NanoSelector selector,
    NanoNode original,
  ) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      await Future<void>.delayed(_stability.wait);
      final snap2 = await snapshot();
      if (snap2 == null || snap2.isEmpty) return null;
      final re = _engine.resolve(selector, snap2);
      final reResolved = re.isResolved ? re.best!.node : null;
      if (_stability.isStable(original: original, reResolved: reResolved)) {
        return reResolved;
      }
    }
    return null;
  }

  /// Mapea un resolve no-ok a su [AgentExecutionResult.failure].
  AgentExecutionResult _statusFailure(ResolveOutcome resolve) {
    final code = switch (resolve.status) {
      ResolveStatus.ambiguous => AgentErrorCode.ambiguousTarget,
      ResolveStatus.notFound => AgentErrorCode.notFound,
      ResolveStatus.resolved || ResolveStatus.serviceOff =>
        AgentErrorCode.serviceOff,
    };
    return AgentExecutionResult.failure(
      errorCode: code,
      reason: resolve.reason,
      resolve: resolve,
    );
  }
}
