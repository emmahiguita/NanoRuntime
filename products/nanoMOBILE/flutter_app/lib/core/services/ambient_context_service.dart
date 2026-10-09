import 'dart:convert';
import 'package:http/http.dart' as http;

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

  const AmbientContext({
    required this.location,
    required this.weather,
    required this.lastUpdated,
    this.source = '',
    this.observationTime = '',
    this.providerArea = '',
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
        'No demuestra ubicación del dueño, observación propia ni clima de una calle.';
  }
}

/// Consulta HTTPS por ciudad explícita; comparte solicitudes y limita caché/red.
class AmbientContextService {
  AmbientContextService._();
  static final AmbientContextService instance = AmbientContextService._();

  final _cache = <String, AmbientContext>{};
  final _flights = <String, Future<AmbientContext?>>{};

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
    if (cached != null && cached.isFresh(DateTime.now())) return cached;
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
      return result;
    } finally {
      _flights.remove(key);
    }
  }

  // Cierra el cliente incluso por timeout: no quedan conexiones huérfanas.
  Future<AmbientContext?> _fetch(String city) async {
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
      final resolvedLocation = city.isNotEmpty ? city : '$area, $country';
      return AmbientContext(
        location: resolvedLocation,
        weather: '$description; $temp °C; humedad $humidity%',
        lastUpdated: DateTime.now(),
        source: uri.toString(),
        observationTime: observed,
        providerArea: '$area, $country',
      );
    } on Object {
      // Un fallo no convierte la caché caducada ni datos incompletos en hechos.
      return null;
    } finally {
      client.close();
    }
  }
}
