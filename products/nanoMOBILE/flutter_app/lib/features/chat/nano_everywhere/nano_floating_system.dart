// nano_floating_system.dart — Canal Flutter → Kotlin para el overlay nativo.
// QUÉ: Expone takePendingEntry, hasPermission, requestPermission, show, hide.
// CÓMO: MethodChannel 'dev.nanoai/floating'. Kotlin responde desde NanoFloatingChannel.
// POR QUÉ: La interfaz es síncrona desde Flutter; el canal es el único puente.
//          const constructor — sin estado, reutilizable sin instanciar.
import 'package:flutter/services.dart';

/// El overlay nativo vive fuera de la Activity de Nano — pide permiso desde un tap.
class NanoFloatingSystem {
  const NanoFloatingSystem();
  static const _channel = MethodChannel('dev.nanoai/floating');

  /// Toma el prompt + modo del overlay nativo (null si no hay pendiente).
  Future<Map<String, dynamic>?> takePendingEntry() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('takePendingEntry');
    return raw?.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<bool> get permitted async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  Future<void> requestPermission() =>
      _channel.invokeMethod<void>('requestPermission');

  Future<bool> show() async =>
      await _channel.invokeMethod<bool>('show') ?? false;

  Future<void> hide() => _channel.invokeMethod<void>('hide');
}
