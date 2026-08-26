/// A14.9 — NotificationDataCandidateProvider: extrae un DATO observado (URL)
/// de la notificación y genera una acción de OTRO dominio (Linux write) para
/// satisfacer objetivos cross-app como "guarda el enlace que envió Juan".
///
/// Determinista, sin LLM. El dato extraído es OBSERVACIÓN (no autoridad): el
/// candidato lleva evidencia notificationCapability; el texto del mensaje no se
/// convierte en comando.
library;

import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/platform_verification.dart' show FileExists;
import '../../execution/tool_registry.dart' show ToolRisk;
import '../../system/system_capability.dart';
import '../../notifications/notification_object.dart';
import '../../notifications/observed_data_extractor.dart';
import 'candidate_action.dart';
import 'candidate_provider.dart';

class NotificationDataCandidateProvider implements CandidateProvider {
  NotificationDataCandidateProvider(this._listNotifications);

  final Future<List<dynamic>> Function() _listNotifications;

  static const _saveTerms = [
    'guarda el enlace',
    'guardar el enlace',
    'guarda el link',
    'guardar el link',
    'guarda lo que envi',
    'guarda la url',
    'guardar url',
    'save the link',
    'save link',
  ];

  static const _openTerms = [
    'abre el enlace',
    'abrir el enlace',
    'abre el link',
    'abrir el link',
    'abre la url',
    'abrir url',
    'open the link',
    'open link',
  ];

  @override
  String get id => 'notificationData';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final goal = request.goal.toLowerCase();
    final isSave = _saveTerms.any(goal.contains);
    final isOpen = _openTerms.any(goal.contains);
    if (!isSave && !isOpen) return const [];

    final raw = await _listNotifications();
    final notifications = raw
        .whereType<Map>()
        .map((m) => NotificationObject.fromMap(m.cast<dynamic, dynamic>()))
        .where((n) => n.interpretableText.isNotEmpty)
        .toList();
    if (notifications.isEmpty) return const [];

    // El dato accionable: URL del mensaje más reciente (o del target nombrado).
    final target = request.continuationTarget?.toLowerCase();
    final source = _find(notifications, target) ?? notifications.first;
    final data = const ObservedDataExtractor().extract(
      source.interpretableText,
    );
    final url = data.primary;
    if (url == null) return const [];

    if (isOpen) {
      return [
        CandidateAction(
          id: CandidateId('notification:open:${source.packageName}'),
          semanticAction: 'open_observed_url',
          tool: 'open_url',
          args: {'url': url, 'source': source.identity},
          channel: ActionChannel.androidIntent,
          groundingConfidence: 0.85,
          risk: ToolRisk.device,
          reversible: true,
          requiredCapabilities: const {SystemCapability.openSystemSettings},
          evidence: [
            ActionEvidence(
              source: ActionEvidenceSource.notificationCapability,
              reference: 'url:${url.hashCode}',
              confidence: 0.85,
            ),
          ],
        ),
      ];
    }

    // Path por defecto en el rootfs de Nano (el usuario no especificó destino).
    const path = '/root/nano_observed_link.txt';
    return [
      CandidateAction(
        id: CandidateId('notification:save:${source.packageName}'),
        semanticAction: 'save_observed_data',
        tool: 'linux.writeFile',
        args: {'path': path, 'content': url, 'source': source.identity},
        channel: ActionChannel.linux,
        groundingConfidence: 0.8,
        risk: ToolRisk.device,
        reversible: true,
        requiredCapabilities: const {SystemCapability.linuxExecution},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.notificationCapability,
            reference: 'url:${url.hashCode}',
            confidence: 0.8,
          ),
        ],
        expectation: const ActionExpectation(
          platformPredicates: [FileExists(path)],
        ),
      ),
    ];
  }

  NotificationObject? _find(
    List<NotificationObject> notifications,
    String? target,
  ) {
    if (target == null || target.isEmpty) return null;
    for (final n in notifications) {
      final hay = '${n.sender} ${n.conversationTitle}'.toLowerCase();
      if (hay.contains(target)) return n;
    }
    return null;
  }
}
