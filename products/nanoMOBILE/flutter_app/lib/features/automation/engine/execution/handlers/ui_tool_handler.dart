import '../../browser/chrome_content_extractor.dart' show ChromeContentExtractor;
import '../../perception/nano_selector.dart';
import '../../perception/nano_snapshot.dart' as nano_snapshot;
import '../../system/system_destination.dart' show SystemDestination;
import '../../system/system_intent_launcher.dart' show SystemIntentLauncher;
import '../action_verifier.dart';
import '../agent_executor.dart';
import '../agent_loop.dart';
import '../tool_call.dart';

/// Manejador de herramientas de inspección UI y gestos físicos/globales.
/// Cumple SRP: observación de superficie accesible, resolución de nodos y ejecución de gestos.
class UiToolHandler {
  final AgentExecutor _executor;
  final AgentVerifier _verifier;
  final AgentLoop _loop;
  final Future<bool> Function(String action) _globalAction;
  final Future<bool> Function(int x1, int y1, int x2, int y2, {int durationMs}) _swipe;
  final Future<bool> Function(int x, int y, {int durationMs}) _longPress;
  final SystemIntentLauncher? _systemIntentLauncher;

  const UiToolHandler({
    required AgentExecutor executor,
    required AgentVerifier verifier,
    required AgentLoop loop,
    required Future<bool> Function(String action) globalAction,
    required Future<bool> Function(int x1, int y1, int x2, int y2, {int durationMs}) swipe,
    required Future<bool> Function(int x, int y, {int durationMs}) longPress,
    SystemIntentLauncher? systemIntentLauncher,
  })  : _executor = executor,
        _verifier = verifier,
        _loop = loop,
        _globalAction = globalAction,
        _swipe = swipe,
        _longPress = longPress,
        _systemIntentLauncher = systemIntentLauncher;

  Future<String> describeScreen() async {
    final snap = await _executor.snapshot();
    if (snap == null) {
      return '[serviceOff] Accesibilidad apagada o canal sin respuesta.';
    }
    if (snap.isEmpty) {
      return '[snapshotEmpty] Sin ventana activa (rebind en curso).';
    }
    final visible = snap.visibleNodes;
    final top = visible
        .take(10)
        .map(
          (n) =>
              '${n.depth} ${n.label} '
              '@(${n.bounds.centerX.round()},${n.bounds.centerY.round()})',
        );
    return 'Pantalla "${snap.package}" · ${snap.nodes.length} nodos '
        '(${visible.length} visibles). Top visibles:\n${top.join('\n')}';
  }

  Future<String> readScreenText() async {
    final snap = await _executor.snapshot();
    if (snap == null) {
      return '[serviceOff] Accesibilidad apagada o canal sin respuesta.';
    }
    if (snap.isEmpty) {
      return '[snapshotEmpty] Sin ventana activa (rebind en curso).';
    }
    if (snap.package == 'com.android.chrome') {
      final web = const ChromeContentExtractor().extract(snap);
      if (web.isNotEmpty) {
        final buffer = StringBuffer('Contenido web en Chrome');
        if (web.title.isNotEmpty) buffer.write(' — "${web.title}"');
        if (web.url != null && web.url!.isNotEmpty) buffer.write(' (${web.url})');
        buffer.write(':\n\n${web.rawText}');
        return buffer.toString();
      }
    }
    final texts = <String>[];
    for (final n in snap.visibleNodes) {
      final t = n.label.isNotEmpty
          ? n.label
          : (n.text.isNotEmpty ? n.text : n.description);
      if (t.isNotEmpty && !texts.contains(t)) texts.add(t);
    }
    if (texts.isEmpty) {
      return 'No hay texto visible en "${snap.package}".';
    }
    return 'Texto visible en "${snap.package}":\n${texts.join('\n')}';
  }

  Future<String> resolve(String expr) async {
    final (selector, err) = tryParse(expr);
    if (selector == null) return err!;
    final outcome = await _executor.resolve(selector);
    if (!outcome.isResolved) {
      return '[${outcome.status.name}] ${outcome.reason}';
    }
    final top = outcome.candidates
        .take(5)
        .map(
          (e) =>
              '• "${e.node.label}" — ${e.score} pts [${e.matchedCriteria.join(',')}]',
        );
    return 'Resuelto: "${outcome.best!.node.label}" '
        '(${outcome.best!.score} pts).\n${top.join('\n')}';
  }

  Future<String> tap(ToolCall call) async {
    final (selector, err) = tryParse(call.selectorArg!);
    if (selector == null) return err!;
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    final result = await _loop.run([
      AgentStep(
        id: 'tap(${call.selectorArg})',
        selector: selector,
        action: AgentAction.tap,
        expectation: expectation,
      ),
    ]);
    final sr = result.steps.first;
    if (!sr.execution.ok) {
      return '[${sr.execution.errorCode!.name}] ${sr.execution.reason}';
    }
    final b = sr.execution.targetNode!.bounds;
    final base =
        'tap en "${sr.execution.targetNode!.label}" '
        '@(${b.centerX.round()},${b.centerY.round()})';
    if (result.completed) return base;
    return '[completedUnverified] $base — la acción fue despachada, pero la '
        'postcondición no pudo verificarse: ${sr.verification?.reason}';
  }

  Future<String> write(ToolCall call) async {
    final text = (call.textArg ?? '').trim();
    if (text.isEmpty) {
      return 'Texto vacío en @escribir.';
    }
    final (selector, err) = tryParse(call.selectorArg!);
    if (selector == null) return err!;
    final expectation = expectationFor(
      call,
    ).copyWith(expectedText: text, expectedTextTarget: selector);
    final result = await _loop.run([
      AgentStep(
        id: 'write(${call.selectorArg})',
        selector: selector,
        action: AgentAction.setText,
        text: text,
        expectation: expectation,
      ),
    ]);
    final sr = result.steps.first;
    if (!sr.execution.ok) {
      return '[${sr.execution.errorCode!.name}] ${sr.execution.reason}';
    }
    final base = '"$text" escrito en "${sr.execution.targetNode!.label}"';
    if (result.completed) return base;
    return '[verify:${sr.verification?.status.name}] $base — '
        '${sr.verification?.reason}';
  }

  Future<String> back(ToolCall call) async {
    final pre = await _executor.snapshot();
    final ok = await _globalAction('back');
    if (!ok) return '[gestureFailed] Back falló.';
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    return verifiedFeedback(
      'Botón atrás ejecutado.',
      expectation,
      preSnapshot: pre,
    );
  }

  Future<String> navigate(ToolCall call, String label, String action) async {
    final pre = await _executor.snapshot();
    final ok = await _globalAction(action);
    if (!ok) return '[gestureFailed] $label falló.';
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    return verifiedFeedback(
      '$label ejecutado.',
      expectation,
      preSnapshot: pre,
    );
  }

  Future<String> doSwipe(ToolCall call) async {
    final a = call.args ?? const {};
    final x1 = argInt(a, 'startX');
    final y1 = argInt(a, 'startY');
    final x2 = argInt(a, 'endX');
    final y2 = argInt(a, 'endY');
    if (x1 == null || y1 == null || x2 == null || y2 == null) {
      return '[tool] swipe requiere args {startX,startY,endX,endY} '
          '(y durationMs opcional).';
    }
    final duration = argInt(a, 'durationMs') ?? 300;
    final pre = await _executor.snapshot();
    final ok = await _swipe(x1, y1, x2, y2, durationMs: duration);
    if (!ok) return '[gestureFailed] swipe falló.';
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    return verifiedFeedback(
      'Deslizamiento ejecutado.',
      expectation,
      preSnapshot: pre,
    );
  }

  Future<String> doScroll(ToolCall call) async {
    final direction = call.args?['direction']?.toString().toLowerCase() ?? '';
    if (direction.isEmpty) {
      return '[tool] scroll requiere args {direction: up|down|left|right}.';
    }
    final snap = await _executor.snapshot();
    if (snap == null || snap.isEmpty) {
      return '[snapshotEmpty] Sin ventana activa para calcular el scroll.';
    }
    var sw = 0;
    var sh = 0;
    for (final n in snap.nodes) {
      if (n.bounds.right > sw) sw = n.bounds.right;
      if (n.bounds.bottom > sh) sh = n.bounds.bottom;
    }
    if (sw <= 0 || sh <= 0) {
      return '[snapshotEmpty] Sin bounds de pantalla para calcular el scroll.';
    }
    final cx = sw ~/ 2;
    final cy = sh ~/ 2;
    final dx = (sw * 0.6).round();
    final dy = (sh * 0.6).round();
    final coords = scrollCoords(direction, cx, cy, dx, dy);
    if (coords == null) {
      return '[tool] scroll direction inválida "$direction" '
          '(up|down|left|right).';
    }
    final ok = await _swipe(
      coords.x1,
      coords.y1,
      coords.x2,
      coords.y2,
      durationMs: 300,
    );
    if (!ok) return '[gestureFailed] scroll falló.';
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    return verifiedFeedback(
      'Scroll $direction ejecutado.',
      expectation,
      preSnapshot: snap,
    );
  }

  Future<String> doLongPress(ToolCall call) async {
    final a = call.args ?? const {};
    final x = argInt(a, 'x');
    final y = argInt(a, 'y');
    if (x == null || y == null) {
      return '[tool] long_press requiere args {x,y} (y durationMs opcional).';
    }
    final duration = argInt(a, 'durationMs') ?? 600;
    final pre = await _executor.snapshot();
    final ok = await _longPress(x, y, durationMs: duration);
    if (!ok) return '[gestureFailed] long_press falló.';
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    return verifiedFeedback(
      'Pulsación larga ejecutada.',
      expectation,
      preSnapshot: pre,
    );
  }

  Future<String> openSystem(ToolCall call) async {
    final raw = call.args?['destination']?.toString() ?? '';
    final destination = SystemDestination.fromWireId(raw);
    if (destination == null) {
      return '[tool] open_system requiere args {destination} allowlisted '
          '(settings|wifi_settings|bluetooth_settings).';
    }
    final launcher = _systemIntentLauncher;
    if (launcher == null) {
      return '[unavailable] Navegación de sistema no disponible.';
    }
    final pre = await _executor.snapshot();
    final res = await launcher.open(destination);
    if (!res.opened) {
      return '[launchFailed] No se pudo abrir ${destination.description}: '
          '${res.reason}';
    }
    final expectation = expectationFor(
      call,
    ).copyWith(mustChangeSnapshot: true);
    return verifiedFeedback(
      '${destination.description} abiertos.',
      expectation,
      preSnapshot: pre,
    );
  }

  ActionExpectation expectationFor(ToolCall call) {
    final e = call.expect;
    if (e == null) return const ActionExpectation();
    NanoSelector? parse(Object? raw) {
      if (raw is! String || raw.trim().isEmpty) return null;
      try {
        return NanoSelector.parse(raw);
      } on SelectorFormatException {
        return null;
      }
    }

    String? str(String key) {
      final v = e[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return ActionExpectation(
      expectedPackage: str('package'),
      mustAppear: parse(e['appear']),
      mustDisappear: parse(e['disappear']),
      expectedText: str('text'),
      forbiddenText: str('forbidden'),
    );
  }

  Future<String> verifiedFeedback(
    String success,
    ActionExpectation expectation, {
    nano_snapshot.NanoSnapshot? preSnapshot,
  }) async {
    if (!expectation.hasCriteria) {
      return '[verificationRequired] $success sin postcondición declarada.';
    }
    try {
      final out = await _verifier.verify(expectation, preSnapshot: preSnapshot);
      if (out.isVerified) return '$success · verificado';
      return '[verify:${out.status.name}] $success — ${out.reason}';
    } catch (e) {
      return '[verify:error] $success — $e';
    }
  }

  ({int x1, int y1, int x2, int y2})? scrollCoords(
    String direction,
    int cx,
    int cy,
    int dx,
    int dy,
  ) {
    return switch (direction) {
      'up' => (x1: cx, y1: cy + dy ~/ 2, x2: cx, y2: cy - dy ~/ 2),
      'down' => (x1: cx, y1: cy - dy ~/ 2, x2: cx, y2: cy + dy ~/ 2),
      'left' => (x1: cx + dx ~/ 2, y1: cy, x2: cx - dx ~/ 2, y2: cy),
      'right' => (x1: cx - dx ~/ 2, y1: cy, x2: cx + dx ~/ 2, y2: cy),
      _ => null,
    };
  }

  int? argInt(Map<String, Object?> args, String key) {
    final v = args[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  (NanoSelector?, String?) tryParse(String expr) {
    try {
      return (NanoSelector.parse(expr), null);
    } on SelectorFormatException catch (e) {
      return (null, 'Selector inválido "$expr": ${e.message}');
    }
  }
}
