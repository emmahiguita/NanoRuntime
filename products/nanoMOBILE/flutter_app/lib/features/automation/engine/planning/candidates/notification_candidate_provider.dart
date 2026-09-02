/// A14.6 — NotificationCandidateProvider: convierte notificaciones activas
/// contestables (con RemoteInput REAL) en CandidateAction grounded. Es una
/// capacidad GENÉRICA `reply_notification`, no por-app: cualquier app que
/// publique una notificación de mensajería contestable (WhatsApp, Telegram,
/// Signal, Discord, Slack, Teams, ...) produce el mismo candidato.
///
/// El packageName y la conversationId salen de la evidencia real de Android
/// (NotificationListener + RemoteInput), NUNCA del string del modelo.
library;

import '../../notifications/notification_draft_writer.dart'
    show NotificationDraftSource;
import '../../notifications/notification_object.dart';
import '../../system/system_capability.dart';
import '../../execution/tool_registry.dart' show ToolRisk;
import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/platform_verification.dart'
    show ForegroundPackageEquals;
import '../message_intent_parser.dart';
import 'candidate_action.dart';
import 'candidate_provider.dart';

class NotificationCandidateProvider implements CandidateProvider {
  NotificationCandidateProvider(
    this._listNotifications, {
    this.draftSource,
  });

  /// Fuente de notificaciones activas (raw del canal `notifications`).
  final Future<List<dynamic>> Function() _listNotifications;

  /// Redacción contextual de la respuesta (LLM local gateado): lee el
  /// contenido REAL de la notificación y produce el borrador. null = sin
  /// fuente (el flujo exige texto del usuario o abre la app).
  final NotificationDraftSource? draftSource;

  static const _replyTerms = [
    'responde',
    'responder',
    'responder a',
    'contesta',
    'contestar',
    'contestar a',
    'responde a',
    'reply',
  ];

  @override
  String get id => 'notification';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final goalLower = request.goal.toLowerCase();
    if (!_replyTerms.any(goalLower.contains)) return const [];

    // T2.0 — separar target ("Juan") del texto a enviar ("llego a las 8").
    // Sin esta separación, el needle de matching incluía el mensaje y el reply
    // nunca llevaba `text` (el dispatcher exige key + text).
    final intent = const MessageIntentParser().parse(request.goal);

    final raw = await _listNotifications();
    final notifications = raw
        .whereType<Map>()
        .map((m) => NotificationObject.fromMap(m.cast<dynamic, dynamic>()))
        .where((n) => n.key.isNotEmpty || n.packageName.isNotEmpty)
        .toList();
    if (notifications.isEmpty) return const [];

    final target = _match(intent.recipient, notifications);
    if (target == null) return const [];

    // Ruta más barata primero (A14.7): si la notificación expone RemoteInput,
    // se responde directamente sin abrir la app. El texto viene del usuario
    // ("responde a Juan que llego") o, si no lo dio, del draft contextual que
    // LEE y ENTIENDE el contenido real de la notificación. Sin texto ni draft
    // no hay reply (no se inventa), se cae al path de apertura.
    if (target.canReply && intent.hasMessage) {
      return [_replyCandidate(target, intent.message)];
    }
    if (target.canReply && !intent.hasMessage) {
      final draftSource = this.draftSource;
      if (draftSource != null) {
        final draft = await draftSource(target);
        if (draft != null && draft.trim().isNotEmpty) {
          return [_replyCandidate(target, draft.trim())];
        }
      }
    }
    // Fallback de continuidad: no hay RemoteInput (o no hay texto ni draft)
    // → abrir la app origen (grounded en el packageName real de la
    // notificación) y continuar por UI.
    if (target.packageName.isEmpty) return const [];
    return [_launchCandidate(target)];
  }

  CandidateAction _replyCandidate(NotificationObject target, String text) =>
      CandidateAction(
        id: CandidateId('notification:reply:${target.key}'),
        semanticAction: 'reply',
        tool: 'reply_notification',
        args: {
          'key': target.key,
          'text': text,
          'conversation': target.identity,
        },
        channel: ActionChannel.notification,
        groundingConfidence: target.sender.isNotEmpty ? 0.85 : 0.6,
        risk: ToolRisk.externalWrite,
        reversible: false,
        requiredCapabilities: const {SystemCapability.replyNotifications},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.notificationCapability,
            reference: 'remoteInput:${target.remoteInputKey}',
            confidence: 0.85,
          ),
        ],
      );

  /// Candidato de continuación: abre la app origen de la notificación para
  /// responder por UI cuando no hay RemoteInput. El package sale de la
  /// notificación (evidencia real), NUNCA del LLM. La postcondición exige
  /// `ForegroundPackageEquals(package)`.
  CandidateAction _launchCandidate(NotificationObject target) =>
      CandidateAction(
        id: CandidateId('notification:launch:${target.packageName}'),
        semanticAction: 'open_app',
        tool: 'launch_app',
        args: {
          'packageName': target.packageName,
          'conversation': target.identity,
        },
        channel: ActionChannel.androidIntent,
        groundingConfidence: 0.7,
        risk: ToolRisk.device,
        reversible: true,
        requiredCapabilities: const {SystemCapability.launchApps},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.notificationCapability,
            reference: target.packageName,
            confidence: 0.7,
          ),
        ],
        expectation: ActionExpectation(
          platformPredicates: [ForegroundPackageEquals(target.packageName)],
        ),
      );

  /// Encuentra la conversación a la que el objetivo se refiere. Si el objetivo
  /// nombra un remitente ("responde a Juan"), se busca por coincidencia en
  /// sender/conversationTitle. Si es genérico ("responde"), se toma la más
  /// reciente contestable (la lista ya viene ordenada por postTime desc).
  ///
  /// [recipient] ya viene separado del mensaje por el MessageIntentParser: aquí
  /// solo se compara el NOMBRE, nunca el texto a enviar.
  NotificationObject? _match(
    String recipient,
    List<NotificationObject> candidates,
  ) {
    final needle = recipient.trim();
    if (needle.isEmpty) return candidates.first;

    for (final n in candidates) {
      if (n.matchesRecipient(needle)) return n;
    }
    // Sin coincidencia por nombre, devolver la más reciente (el humano/planner
    // confirmará). No se inventa una conversación que no exista.
    return candidates.first;
  }
}
