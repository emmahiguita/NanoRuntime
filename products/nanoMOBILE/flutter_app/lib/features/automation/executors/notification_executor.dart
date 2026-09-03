import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../engine/notifications/notification_draft_prompt.dart';

class DeviceNotification {
  final String key;
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;
  final bool canReply;
  final bool ongoing;

  const DeviceNotification({
    required this.key,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
    required this.canReply,
    required this.ongoing,
  });

  factory DeviceNotification.fromMap(Map<dynamic, dynamic> map) {
    final epoch = (map['postTime'] as num?)?.toInt() ?? 0;
    return DeviceNotification(
      key: map['key'] as String? ?? '',
      packageName: map['package'] as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(epoch),
      canReply: map['canReply'] as bool? ?? false,
      ongoing: map['ongoing'] as bool? ?? false,
    );
  }
}

class NotificationAccessStatus {
  final bool accessGranted;
  final bool connected;

  const NotificationAccessStatus({
    required this.accessGranted,
    required this.connected,
  });
}

/// Executor de notificaciones: lectura nativa, borrador exclusivamente local
/// y envío confirmado. El texto de la notificación se trata como dato no
/// fiable y nunca se interpreta como una instrucción o llamada de herramienta.
class NotificationExecutor {
  final NanoRuntimeApi _runtime;
  final LLMEngineClient _engine;

  /// Asegura motor local vivo antes de generar (arranca si idle/failed).
  /// Mismo contrato que el agente: sin motor no se inventa salida, se falla
  /// honesto (fallback local / lista vacía).
  final Future<bool> Function(String? modelPath) _ensureReady;

  NotificationExecutor({
    required NanoRuntimeApi runtime,
    required LLMEngineClient engine,
    required Future<bool> Function(String? modelPath) ensureReady,
  }) : _runtime = runtime,
       _engine = engine,
       _ensureReady = ensureReady;

  Future<NotificationAccessStatus> status() async {
    final raw = await _runtime.notificationStatus();
    return NotificationAccessStatus(
      accessGranted: raw['accessGranted'] == true,
      connected: raw['connected'] == true,
    );
  }

  Future<bool> requestAccess() => _runtime.requestNotificationAccess();

  Future<List<DeviceNotification>> list({int limit = 30}) async {
    final raw = await _runtime.listActiveNotifications(limit: limit);
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(DeviceNotification.fromMap)
        .where((item) => item.key.isNotEmpty)
        .toList(growable: false);
  }

  Future<String> generateLocalDraft(DeviceNotification notification) async {
    if (!notification.canReply) {
      throw StateError('La notificación no admite respuesta directa');
    }
    // LLM OPCIONAL: si el motor local responde, redacta el borrador. Si el motor
    // no está disponible o falla, se usa el fallback heurístico local (el LLM
    // nunca es requisito). El contenido de la notificación es dato no confiable:
    // el fallback no lo repite ni lo interpreta como instrucción.
    try {
      if (!await _ensureReady(null)) {
        // Motor sin modelo vivo: saltar directo al fallback local (honesto,
        // sin gastar intentos de conexión contra un puerto muerto).
        throw StateError('motor local no disponible');
      }
      final result = await _engine.generate(
        prompt: notificationDraftPromptFor(
          packageName: notification.packageName,
          title: notification.title,
          text: notification.text,
        ),
        temperature: 0.3,
        maxTokens: 120,
      );
      final draft = result.text.trim();
      if (draft.isNotEmpty) {
        return draft.length <= 2000 ? draft : draft.substring(0, 2000);
      }
    } catch (_) {
      // Motor local no disponible/falló → fallback local.
    }
    return 'Gracias por escribirme. ¿En qué puedo ayudarte?';
  }

  /// SUG-01 — variantes de respuesta para que el usuario elija. LLM OPCIONAL:
  /// sin motor o sin salida utilizable → lista vacía (jamás variantes
  /// genéricas inventadas). El usuario siempre confirma el envío.
  Future<List<String>> generateSuggestions(
    DeviceNotification notification,
  ) async {
    if (!notification.canReply) return const [];
    try {
      if (!await _ensureReady(null)) {
        // Sin motor: sin sugerencias (jamás variantes genéricas inventadas).
        return const [];
      }
      final result = await _engine.generate(
        prompt: notificationSuggestionsPromptFor(
          packageName: notification.packageName,
          title: notification.title,
          text: notification.text,
        ),
        temperature: 0.6,
        maxTokens: 240,
      );
      return parseNotificationSuggestions(
        result.text,
        packageName: notification.packageName,
      );
    } catch (_) {
      // Motor local no disponible/falló → sin sugerencias.
      return const [];
    }
  }

  Future<bool> confirmAndReply(
    DeviceNotification notification,
    String text,
  ) async {
    final clean = text.trim();
    if (!notification.canReply || clean.isEmpty || clean.length > 2000) {
      return false;
    }
    final result = await _runtime.replyToNotification(
      key: notification.key,
      text: clean,
      confirmed: true,
    );
    return result['ok'] == true;
  }
}
