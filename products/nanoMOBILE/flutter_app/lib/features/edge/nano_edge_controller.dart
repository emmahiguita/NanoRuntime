/// EDGE-01 — NanoEdgeController: puerta Dart al overlay del búho.
///
/// Contratos del sprint: showBubble / hideBubble / showPanel / events.
/// Toda llamada devuelve `false` (nunca excepción) cuando el servicio de
/// accesibilidad no está conectado: el overlay es mejora visual, jamás un
/// requisito de ejecución. El contenido ([NanoEdgeContent]) lo resuelven los
/// paneles de contexto (EDGE-03); este controller solo lo transporta.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nano_edge_state.dart';

/// Puerta Dart al overlay nativo.
abstract interface class NanoEdgeController {
  /// Muestra la burbuja del búho sobre la app en foreground.
  Future<bool> showBubble();

  /// Oculta la ventana por completo.
  Future<bool> hideBubble();

  /// Muestra el panel expandido con [content].
  Future<bool> showPanel(NanoEdgeContent content);

  /// true si el servicio de accesibilidad está conectado (overlay posible).
  Future<bool> isAvailable();

  /// Eventos del overlay (bubbleTapped, panelDismissed). Sin listener
  /// nativo conectado el stream simplemente no emite.
  Stream<NanoEdgeEvent> get events;
}

/// Implementación por MethodChannel `com.nanoai/edge` + EventChannel
/// `com.nanoai/edge_events`. Los canales se definen aquí (una sola vez):
/// core/services no conoce esta feature.
final class MethodChannelNanoEdgeController implements NanoEdgeController {
  MethodChannelNanoEdgeController({
    MethodChannel channel = const MethodChannel('com.nanoai/edge'),
    EventChannel eventsChannel = const EventChannel('com.nanoai/edge_events'),
  }) : _channel = channel,
       _eventsChannel = eventsChannel;

  final MethodChannel _channel;
  final EventChannel _eventsChannel;

  @override
  Future<bool> showBubble() async {
    try {
      return await _channel.invokeMethod<bool>('showBubble') ?? false;
    } catch (e) {
      debugPrint('[edge] showBubble error: $e');
      return false;
    }
  }

  @override
  Future<bool> hideBubble() async {
    try {
      return await _channel.invokeMethod<bool>('hide') ?? false;
    } catch (e) {
      debugPrint('[edge] hideBubble error: $e');
      return false;
    }
  }

  @override
  Future<bool> showPanel(NanoEdgeContent content) async {
    try {
      return await _channel.invokeMethod<bool>('showPanel', {
            'title': content.title,
            'body': content.body,
          }) ??
          false;
    } catch (e) {
      debugPrint('[edge] showPanel error: $e');
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      debugPrint('[edge] isAvailable error: $e');
      return false;
    }
  }

  @override
  Stream<NanoEdgeEvent> get events => _eventsChannel
      .receiveBroadcastStream()
      .map((event) => Map<dynamic, dynamic>.from(event as Map))
      .map(nanoEdgeEventFromMap)
      .where((event) => event != null)
      .cast<NanoEdgeEvent>();
}

/// Instancia única del controller del overlay (EDGE-01).
final nanoEdgeControllerProvider = Provider<NanoEdgeController>(
  (ref) => MethodChannelNanoEdgeController(),
);
