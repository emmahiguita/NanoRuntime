/// CAP-ROUTER-01 — CapabilityResolver: decide QUÉ vía de ejecución satisface
/// un [CapabilityIntent] a partir de observación factual. Pieza PURA:
///
/// - NUNCA ejecuta nada (no envía, no abre, no toca MethodChannel).
/// - NUNCA inventa evidencia: sin evidencia → [ExecutionPath.none].
/// - Es determinista: misma observación → misma ruta (nada de LLM aquí;
///   el LLM propone intents, este router solo resuelve la vía).
///
/// Los ejecutores existentes siguen siendo los ÚNICOS ejecutores:
/// `NotificationReplyTransport` (remoteInput), `TaskOrchestrator` + `CommitGuard`
/// (accessibilityGui), intents vía `NanoRuntimeApi` (androidIntent).
/// Este archivo no añade rutas de ejecución: solo las selecciona.
library;

import '../notifications/notification_object.dart';
import '../perception/semantic/screen_graph.dart';
import '../perception/surface_profiles.dart';
import 'capability_intent.dart';
import 'capability_path_policy.dart';
import 'execution_path.dart';

/// Observación factual del sistema en el momento de resolver. Solo
/// referencias a tipos existentes: nada de tipos nuevos de percepción.
final class CapabilityObservation {
  const CapabilityObservation({
    this.notifications = const [],
    this.screenGraph,
  });

  /// Notificaciones activas observadas (con su key y paquete reales).
  final List<NotificationObject> notifications;

  /// Árbol de la pantalla actual, si hay uno utilizable. Null = sin
  /// accesibilidad o árbol no disponible (honesto: se trata como ausencia).
  final ScreenGraph? screenGraph;

  /// Paquete en foreground según la observación. Vacío = desconocido.
  String get foregroundPackage =>
      screenGraph?.package.trim().toLowerCase() ?? '';
}

/// Ruta resuelta con la evidencia factual que la justifica.
final class ResolvedCapabilityRoute {
  const ResolvedCapabilityRoute({
    required this.path,
    required this.reason,
  });

  final ExecutionPath path;

  /// Cadena factual y corta: QUÉ evidencia produjo esta ruta.
  /// Va a logs/journal; jamás se usa para decidir de nuevo.
  final String reason;

  @override
  String toString() => 'ResolvedCapabilityRoute(${path.name}: $reason)';
}

/// Resuelve la vía de ejecución para un intento.
abstract interface class CapabilityResolver {
  ResolvedCapabilityRoute resolve(
    CapabilityIntent intent,
    CapabilityObservation observation,
  );
}

/// Implementación por evidencia: recorre la política de preferencia en
/// orden y devuelve la PRIMERA vía cuya evidencia se cumple. Ninguna se
/// cumple → [ExecutionPath.none] con razón honesta (fail-closed).
final class EvidenceFirstCapabilityResolver implements CapabilityResolver {
  const EvidenceFirstCapabilityResolver({
    this.profiles = const SurfaceProfileRegistry(),
  });

  final SurfaceProfileSource profiles;

  @override
  ResolvedCapabilityRoute resolve(
    CapabilityIntent intent,
    CapabilityObservation observation,
  ) {
    final preference = CapabilityPathPolicy.preferenceFor(intent);
    for (final path in preference) {
      final evidence = _evidenceFor(path, intent, observation);
      if (evidence != null) {
        return ResolvedCapabilityRoute(path: path, reason: evidence);
      }
    }
    return ResolvedCapabilityRoute(
      path: ExecutionPath.none,
      reason: 'ninguna vía con evidencia suficiente para ${intent.describe()}',
    );
  }

  /// Devuelve la evidencia factual si la vía es viable, o null si no lo es.
  String? _evidenceFor(
    ExecutionPath path,
    CapabilityIntent intent,
    CapabilityObservation observation,
  ) {
    switch (path) {
      case ExecutionPath.remoteInput:
        return _remoteInputEvidence(intent, observation);
      case ExecutionPath.accessibilityGui:
        return _accessibilityGuiEvidence(intent, observation);
      case ExecutionPath.androidIntent:
        return _androidIntentEvidence(intent, observation);
      case ExecutionPath.appFunction:
      case ExecutionPath.ocr:
      case ExecutionPath.vision:
        // appFunction: APPFN-01 aún no existe — nunca se resuelve.
        // ocr/vision: observación suplementaria, jamás ruta principal.
        return null;
      case ExecutionPath.none:
        return null;
    }
  }

  /// RemoteInput solo con la notificación EXACTA todavía activa (WA-RI-05:
  /// cualquier desviación entre lo observado y lo activo descalifica).
  String? _remoteInputEvidence(
    CapabilityIntent intent,
    CapabilityObservation observation,
  ) {
    if (intent is! ReplyIntent) return null;
    final ref = intent.capabilityRef;
    if (ref == null || !ref.isUsable) return null;

    final stillActive = observation.notifications.any(
      (n) => n.key == ref.notificationKey && n.packageName == ref.packageName,
    );
    if (!stillActive) return null;

    return 'notificación ${ref.notificationKey} activa con RemoteInput '
        'exacto observado (action=${ref.actionIndex}, '
        'ri=${ref.remoteInputResultKey})';
  }

  /// GUI solo si el árbol de la app objetivo está disponible Y el perfil de
  /// superficie declarativo de la app declara los elementos necesarios.
  String? _accessibilityGuiEvidence(
    CapabilityIntent intent,
    CapabilityObservation observation,
  ) {
    final graph = observation.screenGraph;
    if (graph == null || graph.truncated) return null;

    switch (intent) {
      case ReplyIntent():
        if (graph.package.trim().toLowerCase() !=
            intent.conversationKey.appPackage) {
          return null;
        }
        return _profileEvidence(
          graph.package,
          {SurfaceElementKind.messageInput, SurfaceElementKind.sendAction},
          'conversación objetivo en pantalla con composer y envío '
              'declarados por perfil',
        );
      case OpenConversationIntent():
        if (graph.package.trim().toLowerCase() !=
            intent.conversationKey.appPackage) {
          return null;
        }
        return _profileEvidence(
          graph.package,
          {SurfaceElementKind.searchInput, SurfaceElementKind.searchAction},
          'app objetivo en foreground con búsqueda declarada por perfil '
              '(navegación interna requerida)',
        );
    }
  }

  String? _profileEvidence(
    String packageName,
    Set<SurfaceElementKind> required,
    String tail,
  ) {
    final present = required.every(
      (kind) => profiles.resolve(packageName, kind).isNotEmpty,
    );
    if (!present) return null;
    return '$tail para $packageName';
  }

  /// Intent directo de apertura: solo si el destino NO está ya en
  /// foreground (abrir lo ya abierto no es un efecto necesario).
  String? _androidIntentEvidence(
    CapabilityIntent intent,
    CapabilityObservation observation,
  ) {
    if (intent is! OpenConversationIntent) return null;
    final target = intent.conversationKey.appPackage;
    if (target.isEmpty) return null;
    if (observation.foregroundPackage == target) {
      return null; // ya abierta: la vía intent no aplica
    }
    return 'destino $target distinto del foreground '
        "'${observation.foregroundPackage.isEmpty ? 'desconocido' : observation.foregroundPackage}'";
  }
}
