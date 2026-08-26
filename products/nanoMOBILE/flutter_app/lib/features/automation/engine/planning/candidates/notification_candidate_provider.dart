/// A14.6 — NotificationCandidateProvider: convierte notificaciones activas
/// contestables (con RemoteInput REAL) en CandidateAction grounded. Es una
/// capacidad GENÉRICA `reply_notification`, no por-app: cualquier app que
/// publique una notificación de mensajería contestable (WhatsApp, Telegram,
/// Signal, Discord, Slack, Teams, ...) produce el mismo candidato.
///
/// El packageName y la conversationId salen de la evidencia real de Android
/// (NotificationListener + RemoteInput), NUNCA del string del modelo.
library;

import '../../notifications/notification_object.dart';
import '../../system/system_capability.dart';
import '../../execution/tool_registry.dart' show ToolRisk;
import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/platform_verification.dart'
    show ForegroundPackageEquals;
import 'candidate_action.dart';
import 'candidate_provider.dart';

class NotificationCandidateProvider implements CandidateProvider {
  NotificationCandidateProvider(this._listNotifications);

  /// Fuente de notificaciones activas (raw del canal `notifications`).
  final Future<List<dynamic>> Function() _listNotifications;

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
    final goal = request.goal.toLowerCase();
    if (!_replyTerms.any(goal.contains)) return const [];

    final raw = await _listNotifications();
    final notifications = raw
        .whereType<Map>()
        .map((m) => NotificationObject.fromMap(m.cast<dynamic, dynamic>()))
        .where((n) => n.key.isNotEmpty || n.packageName.isNotEmpty)
        .toList();
    if (notifications.isEmpty) return const [];

    final target = _match(goal, notifications);
    if (target == null) return const [];

    // Ruta más barata primero (A14.7): si la notificación expone RemoteInput,
    // se responde directamente sin abrir la app.
    if (target.canReply) {
      return [_replyCandidate(target)];
    }
    // Fallback de continuidad: no hay RemoteInput → abrir la app origen (grounded
    // en el packageName real de la notificación) y continuar por UI.
    if (target.packageName.isEmpty) return const [];
    return [_launchCandidate(target)];
  }

  CandidateAction _replyCandidate(NotificationObject target) => CandidateAction(
    id: CandidateId('notification:reply:${target.key}'),
    semanticAction: 'reply',
    tool: 'reply_notification',
    args: {'key': target.key, 'conversation': target.identity},
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
  NotificationObject? _match(String goal, List<NotificationObject> candidates) {
    // El fragmento tras el verbo es el target deseado.
    final verb = _replyTerms.firstWhere(goal.contains, orElse: () => '');
    final rest = verb.isEmpty
        ? goal
        : goal.substring(goal.indexOf(verb) + verb.length);
    final target = rest.trim().replaceAll(RegExp(r'[?!.,]'), '');

    if (target.isEmpty) return candidates.first;

    final needle = target.toLowerCase();
    for (final n in candidates) {
      final hay = '${n.sender} ${n.conversationTitle} ${n.title}'.toLowerCase();
      if (hay.contains(needle)) return n;
    }
    // Sin coincidencia por nombre, devolver la más reciente (el humano/planner
    // confirmará). No se inventa una conversación que no exista.
    return candidates.first;
  }
}
