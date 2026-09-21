import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_capability.dart';

/// Argumentos inmutables para el despacho de respuestas en WhatsApp.
///
/// **QUÉ HACE:**
/// Encapsula el payload validado necesario para que `WhatsappReplyAction`
/// despache un texto a través de un `RemoteInput` de notificación de Android.
///
/// **CÓMO FUNCIONA:**
/// Valida la presencia de `notificationKey`, `packageName` y `remoteInputResultKey`,
/// formateando los datos en `ReplyCapabilityRef`.
///
/// **POR QUÉ:**
/// Aplica el principio de responsabilidad única (SRP), desacoplando la validación
/// de entrada de la lógica del adaptador de herramientas.
final class WhatsappReplyArguments implements ToolArguments {
  const WhatsappReplyArguments({
    required this.capability,
    required this.text,
    required this.sourceEventId,
    required this.conversationId,
  });

  factory WhatsappReplyArguments.fromMap(Map<String, dynamic> raw) {
    final text = '${raw['text'] ?? ''}'.trim();
    final notificationKey = '${raw['notificationKey'] ?? ''}'.trim();
    final packageName = '${raw['packageName'] ?? ''}'.trim();
    final remoteInputKey = '${raw['remoteInputResultKey'] ?? ''}'.trim();
    final actionIndex = (raw['actionIndex'] as num?)?.toInt() ?? -1;
    final observedAt = (raw['observedAt'] as num?)?.toInt() ?? 0;
    final fingerprint = '${raw['contextFingerprint'] ?? ''}';
    if (text.isEmpty) throw const FormatException('text es obligatorio.');
    if (notificationKey.isEmpty || packageName.isEmpty || remoteInputKey.isEmpty) {
      throw const FormatException('La capacidad RemoteInput observada es incompleta.');
    }
    return WhatsappReplyArguments(
      capability: ReplyCapabilityRef(
        notificationKey: notificationKey,
        packageName: packageName,
        observedAt: observedAt,
        actionIndex: actionIndex,
        remoteInputResultKey: remoteInputKey,
        contextFingerprint: fingerprint,
      ),
      text: text,
      sourceEventId: '${raw['sourceEventId'] ?? ''}',
      conversationId: '${raw['conversationId'] ?? notificationKey}',
    );
  }

  final ReplyCapabilityRef capability;
  final String text;
  final String sourceEventId;
  final String conversationId;

  @override
  Map<String, Object?> toRedactedMap() => {
    'notificationKey': capability.notificationKey,
    'packageName': capability.packageName,
    'actionIndex': capability.actionIndex,
    'observedAt': capability.observedAt,
    'sourceEventId': sourceEventId,
    'conversationId': conversationId,
    'textLength': text.length,
  };
}
