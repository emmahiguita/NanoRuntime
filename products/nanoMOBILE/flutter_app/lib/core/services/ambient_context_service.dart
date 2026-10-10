import 'dart:convert';
import 'package:http/http.dart' as http;
import 'device_location_service.dart';

/// QUÉ: evidencia meteorológica de un servicio, no ubicación del dispositivo.
/// CÓMO: conserva ciudad consultada, procedencia y momento real de consulta.
/// POR QUÉ: el modelo debe distinguir datos externos de percepción propia.
class AmbientContext {
  final String location;
  final String weather;
  final DateTime lastUpdated;
  final String source;
  final String observationTime;
  final String providerArea;
  final double? accuracyMeters;

  const AmbientContext({
    required this.location,
    required this.weather,
    required this.lastUpdated,
    this.source = '',
    this.observationTime = '',
    this.providerArea = '',
    this.accuracyMeters,
  });

  bool get isEmpty => location.isEmpty || weather.isEmpty || source.isEmpty;

  bool isFresh(DateTime now) {
    final age = now.difference(lastUpdated);
    return !age.isNegative && age < const Duration(minutes: 10);
  }

  String toPromptLine() {
    if (isEmpty) return '';
    return 'Ciudad consultada: $location. Datos reportados: $weather. '
        'Fuente: $source. Área del proveedor: $providerArea. '
        'Hora reportada por el proveedor (sin fecha/zona verificables): $observationTime. '
        'Consulta realizada: ${lastUpdated.toUtc().toIso8601String()}. '
        '${accuracyMeters == null ? '' : 'Precisión aproximada del GPS: ${accuracyMeters!.round()} m. '}'
        'Al responder incluye lugar resuelto, hora de observación y fuente. '
        'No afirmar clima de una calle ni barrio fuera de la evidencia.';
  }
}

/// Consulta HTTPS por ciudad explícita; comparte solicitudes y limita caché/red.
class AmbientContextService {
  AmbientContextService._();
  static final AmbientContextService instance = AmbientContextService._();

  final _cache = <String, AmbientContext>{};
  final _flights = <String, Future<AmbientContext?>>{};
  AmbientContext? _latestForUi;

  /// Evidencia efímera de la última consulta. No se persiste ni se comparte
  /// con automatizaciones; Chat la usa solo en su mensaje más reciente.
  AmbientContext? get latestForUi => _latestForUi;

  // Sin ciudad no existe contexto global: evita mezclar datos de otros chats.
  AmbientContext? get currentContext => null;

  Future<AmbientContext?> getOrFetchAmbientContext({String? city}) async {
    final requested = city?.trim() ?? '';
    if (requested.isNotEmpty &&
        !RegExp(r'^[a-záéíóúüñA-ZÁÉÍÓÚÜÑ ,.-]{2,64}$').hasMatch(requested)) {
      return null;
    }
    final key = requested.isEmpty
        ? '_current_device_location_'
        : requested.toLowerCase();
    final cached = _cache[key];
    if (cached != null && cached.isFresh(DateTime.now())) {
      _latestForUi = cached;
      return cached;
    }
    if (_flights.containsKey(key)) return _flights[key];
    if (_flights.length >= 8) return null;
    final flight = _fetch(requested);
    _flights[key] = flight;
    try {
      final result = await flight;
      if (result != null) {
        _cache.remove(key);
        if (_cache.length >= 8) _cache.remove(_cache.keys.first);
        _cache[key] = result;
      }
      _latestForUi = result;
      return result;
    } finally {
      _flights.remove(key);
    }
  }

  Future<AmbientContext?> getOrFetchForDevice() async {
    final fix = await DeviceLocationService.instance.locateOnce();
    if (fix == null) {
      _latestForUi = null;
      return null;
    }
    final key =
        '${fix.latitude.toStringAsFixed(3)},${fix.longitude.toStringAsFixed(3)}';
    final cached = _cache[key];
    if (cached != null && cached.isFresh(DateTime.now())) {
      _latestForUi = cached;
      return cached;
    }
    final result = await _fetch(
      '${fix.latitude.toStringAsFixed(6)},${fix.longitude.toStringAsFixed(6)}',
      requestedLabel: 'Ubicación actual del dispositivo',
      accuracyMeters: fix.accuracyMeters,
    );
    if (result != null) _cache[key] = result;
    _latestForUi = result;
    return result;
  }

  // Cierra el cliente incluso por timeout: no quedan conexiones huérfanas.
  Future<AmbientContext?> _fetch(
    String city, {
    String? requestedLabel,
    double? accuracyMeters,
  }) async {
    final client = http.Client();
    final path = city.isEmpty ? '/' : '/$city';
    final uri = Uri.https('wttr.in', path, {'format': 'j1', 'lang': 'es'});
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200 || response.bodyBytes.length > 1000000) {
        return null;
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final condition = (data['current_condition'] as List).first as Map;
      final temp = num.tryParse('${condition['temp_C']}');
      final humidity = num.tryParse('${condition['humidity']}');
      final descriptions = condition['lang_es'] ?? condition['weatherDesc'];
      final description = '${(descriptions as List).first['value']}'.trim();
      final observed = '${condition['observation_time'] ?? ''}'.trim();
      if (temp == null ||
          !temp.isFinite ||
          temp < -90 ||
          temp > 65 ||
          humidity == null ||
          !humidity.isFinite ||
          humidity < 0 ||
          humidity > 100 ||
          description.isEmpty ||
          description == 'null' ||
          observed.isEmpty) {
        return null;
      }
      final nearest = (data['nearest_area'] as List).first as Map;
      final area = '${(nearest['areaName'] as List).first['value']}';
      final country = '${(nearest['country'] as List).first['value']}';
      final resolvedLocation =
          requestedLabel ?? (city.isNotEmpty ? city : '$area, $country');
      return AmbientContext(
        location: resolvedLocation,
        weather: '$description; $temp °C; humedad $humidity%',
        lastUpdated: DateTime.now(),
        source: uri.toString(),
        observationTime: observed,
        providerArea: '$area, $country',
        accuracyMeters: accuracyMeters,
      );
    } on Object {
      // Un fallo no convierte la caché caducada ni datos incompletos en hechos.
      return null;
    } finally {
      client.close();
    }
  }
}
