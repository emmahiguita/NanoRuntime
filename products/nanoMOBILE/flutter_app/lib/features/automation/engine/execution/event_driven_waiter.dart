/// EventDrivenWaiter — espera reactiva basada en eventos de accesibilidad.
///
/// Sustituye pausas arbitrarias (p. ej. sleep o delays fijos) y sondeo ciego.
/// Escucha transiciones reales emitidas por el sistema operativo
/// (TYPE_WINDOW_STATE_CHANGED = 32, TYPE_WINDOW_CONTENT_CHANGED = 2048)
/// a través del canal nativo com.nanoai/agent.
///
/// Válvula de seguridad: cuenta con un timeout bounded estricto para evitar
/// que el hilo del agente quede bloqueado indefinidamente si el evento no ocurre.
library;

import 'package:flutter/services.dart';

/// Tipos de eventos de accesibilidad comunes de Android.
abstract final class AccessibilityEventTypes {
  static const int typeViewClicked = 1;
  static const int typeViewFocused = 8;
  static const int typeWindowStateChanged = 32;
  static const int typeViewScrolled = 4096;
  static const int typeWindowContentChanged = 2048;
}

/// Resultado tipado de una espera reactiva por eventos de ventana.
class EventWaitResult {
  /// true si el evento esperado fue detectado antes del timeout.
  final bool detected;

  /// true si la espera venció el plazo de seguridad.
  final bool timeout;

  /// Nombre del paquete de la app que emitió el evento.
  final String packageName;

  /// Nombre de la clase o actividad (si está disponible).
  final String className;

  /// Tipo de evento numérico de Android Accessibility.
  final int eventType;

  /// Marca de tiempo del evento (en milisegundos).
  final int timestamp;

  const EventWaitResult({
    required this.detected,
    required this.timeout,
    this.packageName = '',
    this.className = '',
    this.eventType = 0,
    this.timestamp = 0,
  });

  /// Constructor para timeout o ausencia de evento.
  factory EventWaitResult.timedOut() => const EventWaitResult(
        detected: false,
        timeout: true,
      );

  /// Constructor a partir del mapa nativo devuelto por MethodChannel.
  factory EventWaitResult.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return EventWaitResult.timedOut();
    return EventWaitResult(
      detected: map['detected'] == true,
      timeout: map['timeout'] == true,
      packageName: map['packageName'] as String? ?? '',
      className: map['className'] as String? ?? '',
      eventType: (map['eventType'] as num?)?.toInt() ?? 0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Mecanismo de espera reactivo ante transiciones de ventana y UI.
class EventDrivenWaiter {
  EventDrivenWaiter({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.nanoai/agent');

  final MethodChannel _channel;

  /// Espera reactivamente a que ocurra un evento de accesibilidad en el sistema.
  ///
  /// Desbloquea en el instante exacto en que el sistema operativo despacha el
  /// evento (habitualmente 20-150ms tras un toque o launch), en lugar de esperar
  /// un delay fijo arbitrario.
  Future<EventWaitResult> waitForEvent({
    String? expectedPackage,
    List<int>? eventTypes,
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    try {
      final res = await _channel.invokeMapMethod<dynamic, dynamic>(
        'waitForWindowEvent',
        {
          if (expectedPackage != null && expectedPackage.isNotEmpty)
            'expectedPackage': expectedPackage,
          if (eventTypes != null && eventTypes.isNotEmpty)
            'eventTypes': eventTypes,
          'timeoutMs': timeout.inMilliseconds,
        },
      );
      return EventWaitResult.fromMap(res);
    } on PlatformException {
      return EventWaitResult.timedOut();
    } catch (_) {
      return EventWaitResult.timedOut();
    }
  }

  /// Espera a que una aplicación específica pase a primer plano (cambio de ventana).
  Future<EventWaitResult> waitForPackage(
    String expectedPackage, {
    Duration timeout = const Duration(milliseconds: 2500),
  }) {
    return waitForEvent(
      expectedPackage: expectedPackage,
      eventTypes: const [
        AccessibilityEventTypes.typeWindowStateChanged,
        AccessibilityEventTypes.typeWindowContentChanged,
      ],
      timeout: timeout,
    );
  }

  /// Espera a que la ventana actual transicione o actualice su contenido.
  Future<EventWaitResult> waitForTransition({
    Duration timeout = const Duration(milliseconds: 1500),
  }) {
    return waitForEvent(
      eventTypes: const [
        AccessibilityEventTypes.typeWindowStateChanged,
        AccessibilityEventTypes.typeWindowContentChanged,
      ],
      timeout: timeout,
    );
  }

  /// Consulta el último evento de ventana registrado de forma síncrona/inmediata.
  Future<EventWaitResult?> getLastEvent() async {
    try {
      final res = await _channel.invokeMapMethod<dynamic, dynamic>(
        'getLastWindowEvent',
      );
      if (res == null) return null;
      return EventWaitResult.fromMap(res);
    } catch (_) {
      return null;
    }
  }
}
