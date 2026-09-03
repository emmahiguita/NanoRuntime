/// UNI-01 — ReplyTransport: contrato universal de despacho de respuestas.
///
/// Hoy el executor interpreta `result['ok'] == true` como un bool crudo y
/// pierde la distinción honesta entre "el nativo aceptó el RemoteInput" y
/// "la respuesta llegó". Este port tipa el despacho con el vocabulario que
/// el orchestration ya posee ([SendEvidence] / [SendEvidenceStatus]):
///
/// - `dispatchedUnverified` — el canal aceptó (REMOTE_INPUT_ACCEPTED ≠
///   entrega verificada).
/// - `notExecuted` — el canal rechazó explícitamente: se sabe que no salió.
/// - `outcomeUnknown` — no hay veredicto (excepción o respuesta sin `ok`).
///   NUNCA se reintenta a ciegas desde este estado.
///
/// El transport NO decide autorización ni destino: recibe una
/// [ReplyCapabilityRef] ya revalidada y un texto ya aprobado. Solo despacha
/// y reporta evidencia.
library;

import '../../../../core/services/nano_runtime_api.dart';
import '../orchestration/commit_guard.dart';
import 'reply_capability.dart';

/// Solicitud de despacho de una respuesta: referencia exacta + texto
/// aprobado + confirmación humana del paso previo.
final class ReplyDispatchRequest {
  const ReplyDispatchRequest({
    required this.capability,
    required this.text,
    required this.confirmed,
  });

  /// Referencia revalidada a la capacidad RemoteInput exacta observada.
  final ReplyCapabilityRef capability;

  /// Texto ya aprobado por la cadena de gobernanza (nunca crudo del LLM).
  final String text;

  /// true solo cuando el paso de confirmación humana se cumplió.
  final bool confirmed;

  bool get isUsable =>
      capability.isUsable && text.trim().isNotEmpty && confirmed;
}

/// Despacha una respuesta por el canal correspondiente y devuelve evidencia
/// honesta. Implementaciones: notificación nativa (RemoteInput), gestos
/// asistidos por CommitGuard, o cualquier canal futuro.
abstract interface class ReplyTransport {
  Future<SendEvidence> dispatch(ReplyDispatchRequest request);
}

/// Transporte por RemoteInput nativo vía [NanoRuntimeApi]. Mapea el
/// resultado crudo al vocabulario [SendEvidenceStatus] sin inventar
/// verificación: un `ok: true` del sistema operativo NO prueba entrega.
final class NotificationReplyTransport implements ReplyTransport {
  const NotificationReplyTransport(this._runtime);

  final NanoRuntimeApi _runtime;

  @override
  Future<SendEvidence> dispatch(ReplyDispatchRequest request) async {
    if (!request.isUsable) {
      return const SendEvidence(
        SendEvidenceStatus.notExecuted,
        'referencia de reply inutilizable o texto vacío; no se despachó',
      );
    }

    final capability = request.capability;
    final Map<dynamic, dynamic> result;
    try {
      result = await _runtime.replyToNotification(
        key: capability.notificationKey,
        actionIndex: capability.actionIndex,
        remoteInputKey: capability.remoteInputResultKey,
        contextFingerprint: capability.contextFingerprint,
        text: request.text,
        confirmed: request.confirmed,
      );
    } catch (e) {
      return SendEvidence(
        SendEvidenceStatus.outcomeUnknown,
        'fallo al despachar reply nativo: $e; no se reintenta a ciegas',
      );
    }

    final ok = result['ok'];
    if (ok == true) {
      final code = result['code'] ?? 'SIN_CODIGO';
      return SendEvidence(
        SendEvidenceStatus.dispatchedUnverified,
        'nativo aceptó RemoteInput (code=$code); entrega remota NO verificada',
      );
    }
    if (ok == false) {
      final code = result['code'] ?? 'SIN_CODIGO';
      return SendEvidence(
        SendEvidenceStatus.notExecuted,
        'nativo rechazó el envío (code=$code)',
      );
    }
    return const SendEvidence(
      SendEvidenceStatus.outcomeUnknown,
      'respuesta nativa sin veredicto de envío; no se reintenta a ciegas',
    );
  }
}
