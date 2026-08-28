/// Bloqueo de contexto y verificación local para commits UI irreversibles.
library;

import '../governance/action_confirmation.dart';
import '../perception/semantic/nano_ui_object.dart';
import '../perception/semantic/screen_graph.dart';
import '../perception/surface_resolvers.dart';

typedef ObserveScreenGraph = Future<ScreenGraph?> Function();

final class ActionContext {
  final String packageName;
  final String conversation;
  final String draft;
  final String draftFingerprint;
  final String composerIdentity;
  final String composerSelector;
  final String sendIdentity;
  final String sendSelector;
  final String preSnapshotSignature;
  final Set<String> preExistingDraftObjects;

  const ActionContext({
    required this.packageName,
    required this.conversation,
    required this.draft,
    required this.draftFingerprint,
    required this.composerIdentity,
    required this.composerSelector,
    required this.sendIdentity,
    required this.sendSelector,
    required this.preSnapshotSignature,
    required this.preExistingDraftObjects,
  });
}

enum ContextGuardStatus { ready, changed, incompleteEvidence, unavailable }

final class ContextGuardOutcome {
  final ContextGuardStatus status;
  final String reason;
  final ActionContext? context;

  const ContextGuardOutcome(this.status, this.reason, {this.context});

  bool get ready => status == ContextGuardStatus.ready && context != null;
}

enum SendEvidenceStatus {
  localSendVerified,
  dispatchedUnverified,
  outcomeUnknown,
  contextChanged,
  incompleteEvidence,
}

final class SendEvidence {
  final SendEvidenceStatus status;
  final String reason;

  const SendEvidence(this.status, this.reason);
}

/// Captura y vuelve a validar el contexto inmediatamente antes del tap.
/// Después del único tap reconcilia composer + conversación + eco local.
final class CommitGuard {
  final ObserveScreenGraph _observe;

  const CommitGuard({required ObserveScreenGraph observe}) : _observe = observe;

  Future<ContextGuardOutcome> capture({
    required String conversation,
    required String draft,
  }) async {
    final graph = await _observe();
    if (graph == null || graph.isEmpty) {
      return const ContextGuardOutcome(
        ContextGuardStatus.unavailable,
        'sin ScreenGraph para bloquear el contexto',
      );
    }
    if (graph.truncated) {
      return const ContextGuardOutcome(
        ContextGuardStatus.incompleteEvidence,
        'snapshot incompleto antes del commit irreversible',
      );
    }
    final composer = const InputSurfaceResolver().resolve(
      graph,
      kind: InputSurfaceKind.message,
    );
    final send = const ActionSurfaceResolver().resolve(graph, kind: 'send');
    if (composer == null || send == null) {
      return const ContextGuardOutcome(
        ContextGuardStatus.unavailable,
        'composer o superficie de envío no observables',
      );
    }
    if (!_contains(composer.object.text, draft)) {
      return const ContextGuardOutcome(
        ContextGuardStatus.changed,
        'el composer no contiene el borrador esperado',
      );
    }
    if (!_conversationVisible(graph, conversation, composer.object)) {
      return ContextGuardOutcome(
        ContextGuardStatus.changed,
        'la conversación "$conversation" no está identificada en pantalla',
      );
    }
    final existing = graph.objects
        .where(
          (object) =>
              !object.editable &&
              _normalized(object.text) == _normalized(draft),
        )
        .map(_identity)
        .toSet();
    return ContextGuardOutcome(
      ContextGuardStatus.ready,
      'contexto capturado',
      context: ActionContext(
        packageName: graph.package,
        conversation: conversation,
        draft: draft,
        draftFingerprint: canonicalFingerprint(_normalized(draft)),
        composerIdentity: _identity(composer.object),
        composerSelector: composer.selector,
        sendIdentity: _identity(send.object),
        sendSelector: send.selector,
        preSnapshotSignature: _graphSignature(graph),
        preExistingDraftObjects: existing,
      ),
    );
  }

  Future<ContextGuardOutcome> revalidate(ActionContext context) async {
    final graph = await _observe();
    if (graph == null || graph.isEmpty) {
      return const ContextGuardOutcome(
        ContextGuardStatus.unavailable,
        'contexto no observable inmediatamente antes del envío',
      );
    }
    if (graph.truncated) {
      return const ContextGuardOutcome(
        ContextGuardStatus.incompleteEvidence,
        'snapshot incompleto inmediatamente antes del envío',
      );
    }
    if (graph.package != context.packageName) {
      return ContextGuardOutcome(
        ContextGuardStatus.changed,
        'package cambió de ${context.packageName} a ${graph.package}',
      );
    }
    final composer = const InputSurfaceResolver().resolve(
      graph,
      kind: InputSurfaceKind.message,
    );
    final send = const ActionSurfaceResolver().resolve(graph, kind: 'send');
    if (composer == null ||
        send == null ||
        _identity(composer.object) != context.composerIdentity ||
        _identity(send.object) != context.sendIdentity) {
      return const ContextGuardOutcome(
        ContextGuardStatus.changed,
        'composer o botón de envío cambiaron antes del commit',
      );
    }
    if (!_contains(composer.object.text, context.draft) ||
        !_conversationVisible(graph, context.conversation, composer.object)) {
      return const ContextGuardOutcome(
        ContextGuardStatus.changed,
        'conversación o borrador cambiaron antes del commit',
      );
    }
    return ContextGuardOutcome(
      ContextGuardStatus.ready,
      'contexto intacto',
      context: context,
    );
  }

  Future<SendEvidence> verifyAfterDispatch(ActionContext context) async {
    final graph = await _observe();
    if (graph == null || graph.isEmpty) {
      return const SendEvidence(
        SendEvidenceStatus.outcomeUnknown,
        'tap despachado; no fue posible observar el estado posterior',
      );
    }
    if (graph.package != context.packageName ||
        !_conversationVisibleAfterSend(graph, context.conversation)) {
      return const SendEvidence(
        SendEvidenceStatus.contextChanged,
        'tap despachado, pero el contexto posterior cambió',
      );
    }
    if (graph.truncated) {
      return const SendEvidence(
        SendEvidenceStatus.incompleteEvidence,
        'tap despachado; snapshot posterior incompleto',
      );
    }
    final composer = const InputSurfaceResolver().resolve(
      graph,
      kind: InputSurfaceKind.message,
    );
    if (composer != null && _contains(composer.object.text, context.draft)) {
      return const SendEvidence(
        SendEvidenceStatus.outcomeUnknown,
        'tap despachado, pero el composer aún contiene el borrador',
      );
    }

    final localEcho = graph.objects.where((object) {
      if (!object.visible || object.editable) return false;
      if (_normalized(object.text) != _normalized(context.draft)) return false;
      return !context.preExistingDraftObjects.contains(_identity(object));
    }).isNotEmpty;
    if (localEcho) {
      return const SendEvidence(
        SendEvidenceStatus.localSendVerified,
        'composer vaciado y nueva burbuja local saliente observada',
      );
    }
    return const SendEvidence(
      SendEvidenceStatus.dispatchedUnverified,
      'composer vaciado, pero no se observó una nueva burbuja local saliente',
    );
  }

  static bool _conversationVisible(
    ScreenGraph graph,
    String conversation,
    NanoUiObject composer,
  ) {
    final target = _normalized(conversation);
    if (target.isEmpty) return false;
    return graph.objects.any((object) {
      if (!object.visible || object.editable) return false;
      if (object.bounds.bottom > composer.bounds.top) return false;
      final hay = _normalized(
        '${object.text} ${object.description} ${object.label}',
      );
      return hay.contains(target);
    });
  }

  static bool _conversationVisibleAfterSend(
    ScreenGraph graph,
    String conversation,
  ) {
    final target = _normalized(conversation);
    return target.isNotEmpty &&
        graph.objects.any(
          (object) =>
              object.visible &&
              !object.editable &&
              _normalized(
                '${object.text} ${object.description} ${object.label}',
              ).contains(target),
        );
  }

  static String _identity(NanoUiObject object) => canonicalFingerprint({
    'resourceId': object.resourceId,
    'nativeClass': object.nativeClass,
    'bounds': object.bounds.toString(),
    'sourceIndex': object.sourceIndex,
  });

  static String _graphSignature(ScreenGraph graph) => canonicalFingerprint({
    'package': graph.package,
    'objects': [
      for (final object in graph.objects.where((object) => object.visible))
        '${_identity(object)}:${object.text}:${object.description}',
    ],
  });

  static bool _contains(String value, String expected) =>
      _normalized(value).contains(_normalized(expected));

  static String _normalized(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
