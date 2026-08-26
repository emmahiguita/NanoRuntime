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
    final candidates = raw
        .whereType<Map>()
        .map((m) => NotificationObject.fromMap(m.cast<dynamic, dynamic>()))
        .where((n) => n.canReply && n.key.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return const [];

    final target = _match(goal, candidates);
    if (target == null) return const [];

    return [
      CandidateAction(
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
      ),
    ];
  }

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
