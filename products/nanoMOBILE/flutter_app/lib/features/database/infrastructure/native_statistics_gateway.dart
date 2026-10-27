// QUÉ: puerto/adaptador del kernel estadístico C++20.
// CÓMO: envía únicamente números finitos y recibe seis agregados descriptivos.
// POR QUÉ: evita copiar tablas enteras o ejecutar cálculos pesados en la UI.

import 'package:flutter/services.dart';

abstract interface class StatisticsPort {
  Future<Map<String, dynamic>> summarize(List<double> values);
}

final class NativeStatisticsGateway implements StatisticsPort {
  static const _channel = MethodChannel('com.nanoai/data_studio');
  const NativeStatisticsGateway();

  @override
  Future<Map<String, dynamic>> summarize(List<double> values) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'statistics',
      {'values': values},
    );
    if (result == null) {
      throw StateError('El kernel C++ no devolvió estadísticas.');
    }
    return result;
  }
}
