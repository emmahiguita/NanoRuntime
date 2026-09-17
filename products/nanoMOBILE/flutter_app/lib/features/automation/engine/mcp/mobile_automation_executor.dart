/// Ejecutor modular de acciones móviles MCP con Verificación Real — Nano Mobile Engine
///
/// Invariante fundamental:
/// EXECUTED ≠ VERIFIED.
/// Orquesta el ciclo de vida de la automatización móvil, delegando los gestos
/// táctiles a [MobileGestureExecutor] y comprobando las postcondiciones.
library;

import '../../../../core/services/nano_runtime_api.dart';
import '../execution/action_verifier.dart';
import '../execution/agent_executor.dart';
import '../memory/nano_transcript_ledger.dart';
import '../perception/composite_locator.dart';
import '../perception/nano_selector.dart';
import '../perception/nano_snapshot.dart';
import 'mcp_client_port.dart';
import 'mobile_gesture_executor.dart';

class MobileAutomationExecutor {
  MobileAutomationExecutor({
    required NanoRuntimeApi api,
    required AgentExecutor executor,
    required AgentVerifier verifier,
    required NanoTranscriptLedger ledger,
    required NanoCompositeLocator locator,
    MobileGestureExecutor? gestures,
  }) : _api = api,
       _executor = executor,
       _verifier = verifier,
       _ledger = ledger,
       _gestures =
           gestures ??
           MobileGestureExecutor(
             api: api,
             executor: executor,
             verifier: verifier,
             ledger: ledger,
             locator: locator,
           );

  final NanoRuntimeApi _api;
  final AgentExecutor _executor;
  final AgentVerifier _verifier;
  final NanoTranscriptLedger _ledger;
  final MobileGestureExecutor _gestures;

  Future<NanoSnapshot?> smokeTestSnapshot() => _executor.snapshot();

  Future<McpToolCallResult> observe(Map<String, Object?> args) async {
    final includeScreenshot = args['includeScreenshot'] == true;
    final raw = await _api.agentDumpAtomicSnapshot(
      includeScreenshot: includeScreenshot,
    );

    if (raw == null) {
      return const McpToolCallResult(
        status: McpOperationStatus.unavailable,
        errorCode: 'SNAPSHOT_UNAVAILABLE',
        message: 'No fue posible capturar el snapshot de accesibilidad.',
      );
    }

    final snapshot = NanoSnapshot.fromRaw(raw);
    return McpToolCallResult(
      status: McpOperationStatus.success,
      structuredContent: {
        'package': snapshot.package,
        'nodesCount': snapshot.nodes.length,
        'visibleNodesCount': snapshot.visibleNodes.length,
        'synchronizationSkewMs': (raw['synchronizationSkewMs'] as num?)
            ?.toDouble(),
        'windowsCount': snapshot.windows.length,
        'truncated': snapshot.truncated,
      },
      message:
          'Observación completada en ${snapshot.package} (${snapshot.visibleNodes.length} nodos interactuables).',
    );
  }

  Future<McpToolCallResult> tap(Map<String, Object?> args) =>
      _gestures.tap(args);

  Future<McpToolCallResult> type(Map<String, Object?> args) =>
      _gestures.type(args);

  Future<McpToolCallResult> swipe(Map<String, Object?> args) =>
      _gestures.swipe(args);

  Future<McpToolCallResult> pressKey(Map<String, Object?> args) =>
      _gestures.pressKey(args);

  Future<McpToolCallResult> launchApp(Map<String, Object?> args) async {
    final pkg = args['packageName'] as String?;
    if (pkg == null || pkg.isEmpty) {
      return const McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'MISSING_PACKAGE',
        message: 'Se requiere packageName.',
      );
    }

    final executionOk = await _api.agentLaunchPackage(pkg);
    if (!executionOk) {
      _recordFailure('launch_app', 'Intent de lanzamiento falló para $pkg');
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: 'LAUNCH_FAILED',
        message: 'Android no pudo lanzar la aplicación $pkg.',
      );
    }

    // VERIFICACIÓN REAL: La app debe estar en primer plano
    final verifyOutcome = await _verifier.verify(
      ActionExpectation(
        expectedPackage: pkg,
        timeout: const Duration(seconds: 3),
      ),
    );
    final verificationOk = verifyOutcome.isVerified;
    final postSnap = verifyOutcome.snapshot ?? await _executor.snapshot();

    _ledger.recordStep(
      actionName: 'launch_app',
      actionDescription: 'Lanzar aplicación $pkg',
      executionOk: executionOk,
      verificationOk: verificationOk,
      postSnapshot: postSnap,
      targetLabel: pkg,
      observedOutcome: verificationOk
          ? 'App en primer plano verificada'
          : 'La app no tomó el foco: ${verifyOutcome.reason}',
    );

    return McpToolCallResult(
      status: verificationOk
          ? McpOperationStatus.success
          : McpOperationStatus.failed,
      structuredContent: {
        'executionOk': executionOk,
        'verificationOk': verificationOk,
        'packageName': pkg,
      },
      message: verificationOk
          ? 'Aplicación $pkg lanzada y verificada en primer plano.'
          : 'Aplicación $pkg lanzada pero no llegó al primer plano: ${verifyOutcome.reason}',
    );
  }

  Future<McpToolCallResult> verify(Map<String, Object?> args) async {
    final expectedPkg = args['expectedPackage'] as String?;
    final mustAppear = args['mustAppearText'] as String?;
    final mustDisappear = args['mustDisappearText'] as String?;

    final expectation = ActionExpectation(
      expectedPackage: expectedPkg,
      mustAppear: mustAppear != null ? NanoSelector(text: mustAppear) : null,
      mustDisappear: mustDisappear != null
          ? NanoSelector(text: mustDisappear)
          : null,
      timeout: const Duration(seconds: 3),
    );

    final outcome = await _verifier.verify(expectation);
    return McpToolCallResult(
      status: outcome.isVerified
          ? McpOperationStatus.success
          : McpOperationStatus.failed,
      structuredContent: {
        'verified': outcome.isVerified,
        'package': outcome.snapshot?.package,
        'reason': outcome.reason,
      },
      message: outcome.isVerified
          ? 'Postcondición verificada con éxito.'
          : 'Verificación fallida: ${outcome.reason}',
    );
  }

  McpToolCallResult getLedgerHistory() {
    return McpToolCallResult(
      status: McpOperationStatus.success,
      structuredContent: {
        'totalSteps': _ledger.totalSteps,
        'steps': _ledger.allSteps.map((s) => s.toSummaryMap()).toList(),
      },
      message: _ledger.buildContextSummary(),
    );
  }

  void _recordFailure(String action, String reason) {
    _ledger.recordStep(
      actionName: action,
      actionDescription: reason,
      executionOk: false,
      verificationOk: false,
    );
  }
}
