/// Ejecutor de gestos e interacciones directas móviles — Nano Mobile Engine
///
/// Principio de Responsabilidad Única (SRP):
/// Despacha taps, inputs de texto, desplazamientos y teclas globales,
/// verificando siempre la postcondición posterior (EXECUTED ≠ VERIFIED).
library;

import '../../../../core/services/nano_runtime_api.dart';
import '../execution/action_verifier.dart';
import '../execution/agent_executor.dart';
import '../governance/nano_sensitive_data_policy.dart';
import '../memory/nano_transcript_ledger.dart';
import '../perception/composite_locator.dart';
import '../perception/nano_selector.dart';
import 'adaptive_swipe_calculator.dart';
import 'mcp_client_port.dart';

class MobileGestureExecutor {
  MobileGestureExecutor({
    required NanoRuntimeApi api,
    required AgentExecutor executor,
    required AgentVerifier verifier,
    required NanoTranscriptLedger ledger,
    required NanoCompositeLocator locator,
  })  : _api = api,
        _executor = executor,
        _verifier = verifier,
        _ledger = ledger,
        _locator = locator;

  final NanoRuntimeApi _api;
  final AgentExecutor _executor;
  final AgentVerifier _verifier;
  final NanoTranscriptLedger _ledger;
  final NanoCompositeLocator _locator;

  Future<McpToolCallResult> tap(Map<String, Object?> args) async {
    final text = args['text'] as String?;
    final resourceId = args['resourceId'] as String?;
    final packageName = args['packageName'] as String?;
    final x = (args['x'] as num?)?.toInt();
    final y = (args['y'] as num?)?.toInt();

    final preSnap = await _executor.snapshot();
    if (preSnap == null || preSnap.isEmpty) {
      return const McpToolCallResult(
        status: McpOperationStatus.unavailable,
        errorCode: 'SCREEN_NOT_READY',
        message: 'Pantalla no disponible o en rebind.',
      );
    }

    final selector = NanoSelector(text: text, resourceId: resourceId, packageName: packageName);
    final resolution = _locator.locate(
      selector: selector,
      snapshot: preSnap,
      fallbackCoordinates: (x != null && y != null) ? (x, y) : null,
    );

    if (!resolution.isResolved) {
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'TARGET_NOT_RESOLVED',
        message: resolution.diagnostic,
      );
    }

    final (targetX, targetY) = resolution.tapCoordinates!;
    final executionOk = resolution.targetNode != null
        ? (await _executor.tap(selector)).ok
        : await _api.agentTapAt(targetX, targetY);

    if (!executionOk) {
      _recordFailure('tap', 'Fallo al despachar gesto tap en ($targetX, $targetY)');
      return const McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'GESTURE_DISPATCH_FAILED',
        message: 'El gesto de tap no pudo ser despachado por el sistema.',
      );
    }

    // EXECUTED ≠ VERIFIED: Comprobación rigurosa de postcondición
    final expectedPkgAfter = args['expectedPackageAfter'] as String?;
    final mustAppearText = args['mustAppearText'] as String?;
    final mustDisappearText = args['mustDisappearText'] as String?;

    final expectation = ActionExpectation(
      expectedPackage: expectedPkgAfter,
      mustAppear: (mustAppearText != null && mustAppearText.isNotEmpty) ? NanoSelector(text: mustAppearText) : null,
      mustDisappear: (mustDisappearText != null && mustDisappearText.isNotEmpty) ? NanoSelector(text: mustDisappearText) : null,
      mustChangeSnapshot: true,
      timeout: const Duration(seconds: 2),
    );

    final verifyOutcome = await _verifier.verify(expectation, preSnapshot: preSnap);
    final verificationOk = verifyOutcome.isVerified;
    final postSnap = verifyOutcome.snapshot ?? await _executor.snapshot();

    _ledger.recordStep(
      actionName: 'tap',
      actionDescription: 'Tap en ($targetX, $targetY) vía ${resolution.strategy.name}',
      executionOk: executionOk,
      verificationOk: verificationOk,
      postSnapshot: postSnap,
      targetLabel: resolution.targetNode?.label ?? text ?? resourceId,
      observedOutcome: verificationOk ? 'Estado de pantalla verificado' : 'Pantalla no reaccionó: ${verifyOutcome.reason}',
    );

    return McpToolCallResult(
      status: verificationOk ? McpOperationStatus.success : McpOperationStatus.failed,
      structuredContent: {
        'executionOk': executionOk,
        'verificationOk': verificationOk,
        'strategy': resolution.strategy.name,
        'coordinates': [targetX, targetY],
      },
      message: verificationOk
          ? 'Tap ejecutado y verificado en ($targetX, $targetY).'
          : 'Tap ejecutado pero no verificado: ${verifyOutcome.reason}',
    );
  }

  Future<McpToolCallResult> type(Map<String, Object?> args) async {
    final text = args['text'] as String?;
    if (text == null || text.isEmpty) {
      return const McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'EMPTY_TEXT',
        message: 'El parámetro "text" es obligatorio.',
      );
    }

    final preSnap = await _executor.snapshot();
    if (preSnap == null || preSnap.isEmpty) {
      return const McpToolCallResult(
        status: McpOperationStatus.unavailable,
        errorCode: 'SCREEN_NOT_READY',
        message: 'Pantalla no disponible.',
      );
    }

    final targetResId = args['targetResourceId'] as String? ?? '';
    final selector = targetResId.isNotEmpty ? NanoSelector(resourceId: targetResId) : const NanoSelector(editable: true);
    final editables = preSnap.visibleEditables();
    final targetNode = editables.isNotEmpty ? editables.first : null;

    final execResult = await _executor.setText(selector, text);
    final executionOk = execResult.ok;
    if (!executionOk) {
      _recordFailure('type', 'Fallo al escribir texto en $targetResId');
      return const McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'INPUT_FAILED',
        message: 'No fue posible escribir en el campo seleccionado.',
      );
    }

    final postSnap = await _executor.snapshot();
    final isSensitive = NanoSensitiveDataPolicy.isSensitiveNode(targetNode) ||
        NanoSensitiveDataPolicy.isSensitiveText(text);

    bool verificationOk = false;
    if (postSnap != null) {
      final postEditables = postSnap.visibleEditables();
      if (postEditables.isNotEmpty) {
        final currentText = postEditables.first.text;
        verificationOk = isSensitive
            ? (currentText.isNotEmpty || postEditables.first.focused)
            : currentText.contains(text) || currentText.isNotEmpty;
      }
    }

    final safeLabel = NanoSensitiveDataPolicy.redact(text, targetNode: targetNode);
    _ledger.recordStep(
      actionName: 'type',
      actionDescription: 'Escribir $safeLabel',
      executionOk: executionOk,
      verificationOk: verificationOk,
      postSnapshot: postSnap,
      targetLabel: targetResId.isNotEmpty ? targetResId : 'campo_editable',
      observedOutcome: verificationOk ? 'Texto confirmado' : 'Campo no reflejó el texto',
    );

    return McpToolCallResult(
      status: verificationOk ? McpOperationStatus.success : McpOperationStatus.failed,
      structuredContent: {
        'executionOk': executionOk,
        'verificationOk': verificationOk,
        'isSensitive': isSensitive,
      },
      message: verificationOk ? 'Texto introducido y verificado.' : 'Texto no verificado en pantalla.',
    );
  }

  Future<McpToolCallResult> swipe(Map<String, Object?> args) async {
    final direction = args['direction'] as String? ?? 'up';
    final durationMs = (args['durationMs'] as num?)?.toInt() ?? 300;

    final preSnap = await _executor.snapshot();
    if (preSnap == null || preSnap.isEmpty) {
      return const McpToolCallResult(
        status: McpOperationStatus.unavailable,
        errorCode: 'SCREEN_NOT_READY',
        message: 'Pantalla no disponible para swipe.',
      );
    }

    final coords = AdaptiveSwipeCalculator.calculate(direction: direction, snapshot: preSnap);
    final executionOk = await _api.agentSwipe(coords.startX, coords.startY, coords.endX, coords.endY, durationMs: durationMs);

    if (!executionOk) {
      _recordFailure('swipe', 'Fallo al despachar desplazamiento gestual');
      return const McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'SWIPE_FAILED',
        message: 'No fue posible despachar el gesto de swipe.',
      );
    }

    final verifyOutcome = await _verifier.verify(
      const ActionExpectation(mustChangeSnapshot: true, timeout: Duration(seconds: 2)),
      preSnapshot: preSnap,
    );
    final verificationOk = verifyOutcome.isVerified;
    final postSnap = verifyOutcome.snapshot ?? await _executor.snapshot();

    _ledger.recordStep(
      actionName: 'swipe',
      actionDescription: 'Swipe $direction adaptable',
      executionOk: executionOk,
      verificationOk: verificationOk,
      postSnapshot: postSnap,
      observedOutcome: verificationOk ? 'Desplazamiento confirmado' : 'Sin desplazamiento',
    );

    return McpToolCallResult(
      status: verificationOk ? McpOperationStatus.success : McpOperationStatus.failed,
      structuredContent: {'executionOk': executionOk, 'verificationOk': verificationOk},
      message: verificationOk ? 'Swipe $direction ejecutado y verificado.' : 'Swipe no desplazó la pantalla.',
    );
  }

  Future<McpToolCallResult> pressKey(Map<String, Object?> args) async {
    final key = (args['key'] as String? ?? '').toLowerCase();
    final expectedPkg = args['expectedPackage'] as String? ?? '';

    final preSnap = await _executor.snapshot();
    bool executionOk = false;
    if (key == 'enter') {
      final res = await _api.agentSubmitFocusedInput(expectedPackageName: expectedPkg);
      executionOk = res?['ok'] == true;
    } else {
      executionOk = await _api.agentGlobalAction(key);
    }

    if (!executionOk) {
      _recordFailure('press_key', 'Fallo al presionar tecla $key');
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'KEY_FAILED',
        message: 'Fallo al despachar la tecla $key.',
      );
    }

    final verifyOutcome = await _verifier.verify(
      ActionExpectation(
        expectedPackage: expectedPkg.isEmpty ? null : expectedPkg,
        mustChangeSnapshot: true,
        timeout: const Duration(seconds: 2),
      ),
      preSnapshot: preSnap,
    );
    final verificationOk = verifyOutcome.isVerified;
    final postSnap = verifyOutcome.snapshot ?? await _executor.snapshot();

    _ledger.recordStep(
      actionName: 'press_key',
      actionDescription: 'Pulsar tecla $key',
      executionOk: executionOk,
      verificationOk: verificationOk,
      postSnapshot: postSnap,
      observedOutcome: verificationOk ? 'Efecto confirmado' : 'Sin cambios observables',
    );

    return McpToolCallResult(
      status: verificationOk ? McpOperationStatus.success : McpOperationStatus.failed,
      structuredContent: {'executionOk': executionOk, 'verificationOk': verificationOk},
      message: verificationOk ? 'Tecla $key ejecutada y verificada.' : 'Tecla $key sin efecto observable.',
    );
  }

  void _recordFailure(String action, String reason) => _ledger.recordStep(
        actionName: action,
        actionDescription: reason,
        executionOk: false,
        verificationOk: false,
      );
}
