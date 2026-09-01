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
  final String conversationIdentity;
  final int composerCenterX;
  final int composerTop;
  final bool outgoingOnRight;
  final int preOutgoingDraftCount;

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
    required this.conversationIdentity,
    required this.composerCenterX,
    required this.composerTop,
    required this.outgoingOnRight,
    required this.preOutgoingDraftCount,
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
    final conversationObject = _conversationObject(
      graph,
      conversation,
      composer.object,
    );
    if (conversationObject == null) {
      return ContextGuardOutcome(
        ContextGuardStatus.changed,
        'la conversación "$conversation" no está identificada en pantalla',
      );
    }
    final outgoingOnRight =
        send.object.bounds.centerX >= composer.object.bounds.centerX;
    final draftFingerprint = canonicalFingerprint(_normalized(draft));
    final preOutgoingDraftCount = _outgoingDraftObjects(
      graph,
      draftFingerprint: draftFingerprint,
      composerCenterX: composer.object.bounds.centerX,
      composerTop: composer.object.bounds.top,
      outgoingOnRight: outgoingOnRight,
    ).length;
    return ContextGuardOutcome(
      ContextGuardStatus.ready,
      'contexto capturado',
      context: ActionContext(
        packageName: graph.package,
        conversation: conversation,
        draft: draft,
        draftFingerprint: draftFingerprint,
        composerIdentity: _identity(composer.object),
        composerSelector: composer.selector,
        sendIdentity: _identity(send.object),
        sendSelector: send.selector,
        preSnapshotSignature: _graphSignature(graph),
        conversationIdentity: _identity(conversationObject),
        composerCenterX: composer.object.bounds.centerX,
        composerTop: composer.object.bounds.top,
        outgoingOnRight: outgoingOnRight,
        preOutgoingDraftCount: preOutgoingDraftCount,
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
        !_conversationIdentityVisible(graph, context)) {
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
    var best = await _verifyAfterDispatchOnce(context);
    if (_isDefinitive(best)) return best;

    // El tap irreversible ocurre UNA vez. Solo reconciliamos evidencia porque
    // WhatsApp y otras apps pueden publicar el nuevo árbol de accesibilidad uno
    // o dos frames después de vaciar el composer.
    for (final delay in const [
      Duration(milliseconds: 140),
      Duration(milliseconds: 280),
    ]) {
      await Future<void>.delayed(delay);
      final observed = await _verifyAfterDispatchOnce(context);
      if (_isDefinitive(observed)) return observed;
      if (_evidenceRank(observed.status) > _evidenceRank(best.status)) {
        best = observed;
      }
    }
    return best;
  }

  Future<SendEvidence> _verifyAfterDispatchOnce(ActionContext context) async {
    final graph = await _observe();
    if (graph == null || graph.isEmpty) {
      return const SendEvidence(
        SendEvidenceStatus.outcomeUnknown,
        'tap despachado; no fue posible observar el estado posterior',
      );
    }
    if (graph.package != context.packageName ||
        !_conversationIdentityVisible(graph, context)) {
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
    if (composer == null ||
        _identity(composer.object) != context.composerIdentity) {
      return const SendEvidence(
        SendEvidenceStatus.contextChanged,
        'tap despachado, pero el composer cambió o dejó de ser observable',
      );
    }
    if (_contains(composer.object.text, context.draft)) {
      return const SendEvidence(
        SendEvidenceStatus.outcomeUnknown,
        'tap despachado, pero el composer aún contiene el borrador',
      );
    }
    if (_graphSignature(graph) == context.preSnapshotSignature) {
      return const SendEvidence(
        SendEvidenceStatus.outcomeUnknown,
        'tap despachado, pero no se observó transición de pantalla',
      );
    }

    final outgoingDraftCount = _outgoingDraftObjects(
      graph,
      draftFingerprint: context.draftFingerprint,
      composerCenterX: context.composerCenterX,
      composerTop: context.composerTop,
      outgoingOnRight: context.outgoingOnRight,
    ).length;
    if (outgoingDraftCount > context.preOutgoingDraftCount) {
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

  static bool _isDefinitive(SendEvidence evidence) =>
      evidence.status == SendEvidenceStatus.localSendVerified ||
      evidence.status == SendEvidenceStatus.contextChanged;

  static int _evidenceRank(SendEvidenceStatus status) => switch (status) {
    SendEvidenceStatus.localSendVerified => 5,
    SendEvidenceStatus.dispatchedUnverified => 4,
    SendEvidenceStatus.incompleteEvidence => 3,
    SendEvidenceStatus.outcomeUnknown => 2,
    SendEvidenceStatus.contextChanged => 1,
  };

  static NanoUiObject? _conversationObject(
    ScreenGraph graph,
    String conversation,
    NanoUiObject composer,
  ) {
    final target = _normalized(conversation);
    if (target.isEmpty) return null;
    NanoUiObject? best;
    for (final object in graph.objects) {
      if (!object.visible || object.editable) continue;
      if (object.bounds.bottom > composer.bounds.top) continue;
      final hay = _normalized(
        '${object.text} ${object.description} ${object.label}',
      );
      if (!hay.contains(target)) continue;
      if (best == null || object.bounds.top < best.bounds.top) {
        best = object;
      }
    }
    return best;
  }

  static bool _conversationIdentityVisible(
    ScreenGraph graph,
    ActionContext context,
  ) => graph.objects.any(
    (object) =>
        object.visible &&
        !object.editable &&
        _identity(object) == context.conversationIdentity &&
        _normalized(
          '${object.text} ${object.description} ${object.label}',
        ).contains(_normalized(context.conversation)),
  );

  static List<NanoUiObject> _outgoingDraftObjects(
    ScreenGraph graph, {
    required String draftFingerprint,
    required int composerCenterX,
    required int composerTop,
    required bool outgoingOnRight,
  }) => graph.objects
      .where((object) {
        if (!object.visible || object.editable) return false;
        if (object.bounds.bottom > composerTop) return false;
        if (canonicalFingerprint(_normalized(object.text)) !=
            draftFingerprint) {
          return false;
        }
        return outgoingOnRight
            ? object.bounds.centerX >= composerCenterX
            : object.bounds.centerX <= composerCenterX;
      })
      .toList(growable: false);

  static String _identity(NanoUiObject object) {
    // `sourceIndex` y bounds describen una captura, no la identidad del
    // control: al insertar la burbuja enviada WhatsApp reordena el árbol y el
    // compositor puede moverse unos píxeles aunque siga siendo el mismo nodo.
    // Un resourceId observado dentro de la misma ventana es el ancla estable.
    if (object.resourceId.isNotEmpty) {
      return canonicalFingerprint({
        'package': object.packageName,
        'windowId': object.windowId,
        'resourceId': object.resourceId,
        'nativeClass': object.nativeClass,
      });
    }
    // Fallback para controles sin id: conserva suficiente estructura sin usar
    // el ordinal volátil del snapshot.
    return canonicalFingerprint({
      'package': object.packageName,
      'windowId': object.windowId,
      'root': object.rootIdentity,
      'nativeClass': object.nativeClass,
      'label': object.label,
      'description': object.description,
      'bounds': object.bounds.toString(),
    });
  }

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
