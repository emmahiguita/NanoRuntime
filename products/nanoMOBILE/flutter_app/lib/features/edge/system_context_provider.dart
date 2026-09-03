/// EDGE-02 — SystemContextProvider: UN observable de contexto del sistema
/// para alimentar el overlay del búho.
///
/// Reglas duras del sprint:
/// - Solo FUSIÓN de fuentes existentes (accesibilidad, notificaciones,
///   métricas de dispositivo). Cero ejecución, cero llamadas nuevas al
///   sistema, cero escritura.
/// - Cada snapshot se anota con [SystemContextSnapshot.observedAt]: el
///   consumidor sabe cuán fresco es lo que ve (honestidad).
/// - Las fuentes que aún no exponen un contexto en Dart (asistencia por
///   voz) quedan en null — jamás se inventa un valor.
library;

import 'dart:async';

import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';

import 'assistant_role.dart';

/// Resumen derivado del [ScreenGraph] actual (solo lectura, sin acciones).
final class ScreenGraphSummary {
  const ScreenGraphSummary({
    required this.package,
    required this.truncated,
    this.visibleTexts = const [],
  });

  final String package;
  final bool truncated;

  /// Primeros textos visibles del árbol (máx 6): suficiente para que un
  /// panel de contexto diga "estás en X, viendo Y" sin volcar el árbol.
  final List<String> visibleTexts;

  factory ScreenGraphSummary.fromGraph(ScreenGraph graph) => ScreenGraphSummary(
    package: graph.package,
    truncated: graph.truncated,
    visibleTexts: graph.objects
        .where((object) => object.visible && object.text.trim().isNotEmpty)
        .map((object) => object.text.trim())
        .take(6)
        .toList(),
  );
}

/// Estado del dispositivo derivado de DeviceMetricsProvider (canal
/// existente). Todos los campos nullable: métrica ausente = desconocida.
final class DeviceState {
  const DeviceState({
    this.batteryPct,
    this.isCharging,
    this.ramAvailableMb,
    this.ramTotalMb,
    this.storageFreeGb,
    this.cpuTempC,
    this.cpuCores,
  });

  final double? batteryPct;
  final bool? isCharging;
  final double? ramAvailableMb;
  final double? ramTotalMb;
  final double? storageFreeGb;
  final double? cpuTempC;
  final int? cpuCores;

  factory DeviceState.fromMetricsMap(Map<dynamic, dynamic> map) => DeviceState(
    batteryPct: (map['batteryPct'] as num?)?.toDouble(),
    isCharging: map['isCharging'] as bool?,
    ramAvailableMb: (map['ramAvailableMb'] as num?)?.toDouble(),
    ramTotalMb: (map['ramTotalMb'] as num?)?.toDouble(),
    storageFreeGb: (map['storageFreeGb'] as num?)?.toDouble(),
    cpuTempC: (map['cpuTempC'] as num?)?.toDouble(),
    cpuCores: (map['cpuCores'] as num?)?.toInt(),
  );
}

/// Contexto del trigger de asistencia (voz). ROLE-01 expone la sesión viva
/// vía [AssistantRoleManager.isSessionActive] (contador de onCreate/onDestroy
/// en NanoVoiceInteractionSession): factual, jamás inventado.
final class AssistContext {
  const AssistContext({required this.sessionActive});

  final bool sessionActive;
}

/// Snapshot fusionado del sistema en un instante. Inmutable y honesto.
final class SystemContextSnapshot {
  const SystemContextSnapshot({
    required this.observedAt,
    required this.foregroundPackage,
    this.notifications = const [],
    this.screenGraphSummary,
    this.deviceState,
    this.assistContext,
  });

  /// Instante de observación: el consumidor decide si un snapshot viejo
  /// merece mostrarse o no.
  final DateTime observedAt;

  /// Paquete en foreground según el árbol de accesibilidad ("" = desconocido).
  final String foregroundPackage;

  /// Notificaciones activas observadas.
  final List<NotificationObject> notifications;

  final ScreenGraphSummary? screenGraphSummary;
  final DeviceState? deviceState;
  final AssistContext? assistContext;

  bool get isFresh =>
      DateTime.now().difference(observedAt) < const Duration(seconds: 15);
}

/// Observa el contexto del sistema fusionando fuentes existentes.
abstract interface class SystemContextProvider {
  /// Stream de snapshots (emite al suscribirse y en cada ciclo de refresco).
  Stream<SystemContextSnapshot> watch();

  /// Snapshot inmediato (una sola observación).
  Future<SystemContextSnapshot> current();
}

/// Implementación sobre [NanoRuntimeApi]: accesibilidad (agentDumpSnapshot),
/// notificaciones (listActiveNotifications) y métricas (getMetrics). Las
/// tres son las mismas llamadas que ya usa el módulo de automatización —
/// este provider no añade fuentes nuevas, solo las junta.
final class RuntimeSystemContextProvider implements SystemContextProvider {
  RuntimeSystemContextProvider({
    required NanoRuntimeApi api,
    AssistantRoleManager? assistantRole,
    this.refreshInterval = const Duration(seconds: 5),
  }) : _api = api,
       _assistantRole = assistantRole;

  final NanoRuntimeApi _api;

  /// Fuente de asistencia (ROLE-01). null = no cableada → assistContext
  /// queda null (ausencia honesta, jamás se inventa un valor).
  final AssistantRoleManager? _assistantRole;
  final Duration refreshInterval;

  @override
  Future<SystemContextSnapshot> current() async {
    final observedAt = DateTime.now();

    // Accesibilidad: snapshot enriquecido (package + nodos con depth).
    // Mismo camino que el PerceptionMux: NanoSnapshot.fromRaw → ScreenGraph.
    ScreenGraph? graph;
    try {
      final raw = await _api.agentDumpSnapshot();
      if (raw != null && raw.isNotEmpty) {
        graph = ScreenGraph.fromSnapshot(NanoSnapshot.fromRaw(raw));
      }
    } catch (_) {
      graph = null; // servicio sin conectar: honestamente ausente
    }

    // Notificaciones activas (mismo canal que el pipeline de reglas).
    var notifications = const <NotificationObject>[];
    try {
      final rawList = await _api.listActiveNotifications();
      notifications = rawList
          .whereType<Map>()
          .map((map) => NotificationObject.fromMap(
                Map<dynamic, dynamic>.from(map),
              ))
          .toList();
    } catch (_) {
      notifications = const [];
    }

    // Métricas del dispositivo (DeviceMetricsProvider).
    DeviceState? deviceState;
    try {
      final metrics = await _api.getMetrics();
      if (metrics != null && metrics.isNotEmpty) {
        deviceState = DeviceState.fromMetricsMap(metrics);
      }
    } catch (_) {
      deviceState = null;
    }

    // Asistencia (ROLE-01): sesión viva observada en el servicio nativo.
    AssistContext? assistContext;
    final assistant = _assistantRole;
    if (assistant != null) {
      try {
        assistContext = AssistContext(
          sessionActive: await assistant.isSessionActive(),
        );
      } catch (_) {
        assistContext = null; // canal ausente = honestamente sin trigger
      }
    }

    return SystemContextSnapshot(
      observedAt: observedAt,
      foregroundPackage: graph?.package.trim() ?? '',
      notifications: notifications,
      screenGraphSummary: graph == null
          ? null
          : ScreenGraphSummary.fromGraph(graph),
      deviceState: deviceState,
      assistContext: assistContext,
    );
  }

  @override
  Stream<SystemContextSnapshot> watch() async* {
    yield await current();
    await for (final _ in Stream<void>.periodic(refreshInterval)) {
      yield await current();
    }
  }
}
