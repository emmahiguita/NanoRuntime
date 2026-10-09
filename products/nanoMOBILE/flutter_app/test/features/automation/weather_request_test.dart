import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/runtime_personal_live_context.dart';
import 'package:nanoai/features/automation/engine/language/weather_request.dart';
import 'package:nanoai/core/services/ambient_context_service.dart';

void main() {
  group('WeatherRequest — Reconocimiento de consultas meteorológicas en español', () {
    test('Detecta menciones y preguntas de clima, tiempo y temperatura', () {
      final queries = [
        '¿Cómo está el clima en Medellín?',
        'Dime el tiempo en Bogotá',
        '¿Qué tiempo hace en Cali?',
        '¿Cuál es la temperatura en Madrid?',
        'temperatura de Buenos Aires',
        '¿Va a llover en Barranquilla?',
        '¿Está lloviendo en Cartagena?',
        'El clima en Pereira por favor',
        '¿Hace frío en Pasto?',
        'cuéntame el clima de Bucaramanga',
        'quiero saber el tiempo en Manizales',
      ];

      for (final query in queries) {
        expect(
          WeatherRequest.mentionsWeather(query),
          isTrue,
          reason: 'Fallo al mencionar clima: $query',
        );
        expect(
          WeatherRequest.isQuery(query),
          isTrue,
          reason: 'Fallo al detectar consulta: $query',
        );
      }
    });

    test('Extrae ciudades con distintos prefijos naturales', () {
      expect(WeatherRequest.explicitCity('¿Cómo está el clima en Medellín?'), 'Medellín');
      expect(WeatherRequest.explicitCity('Dime el tiempo en Bogotá hoy'), 'Bogotá');
      expect(WeatherRequest.explicitCity('temperatura de Buenos Aires'), 'Buenos Aires');
      expect(WeatherRequest.explicitCity('El clima para Madrid por favor'), 'Madrid');
      expect(WeatherRequest.explicitCity('¿Qué tiempo hace en Cali?'), 'Cali');
      expect(WeatherRequest.explicitCity('clima de Barranquilla'), 'Barranquilla');
    });

    test('RuntimePersonalLiveContext resuelve evidencia meteorológica con mock', () async {
      final context = RuntimePersonalLiveContext(
        clock: () => DateTime(2026, 10, 7, 20, 45),
        weatherFor: (city) async => AmbientContext(
          location: city,
          weather: 'Soleado; 24 °C; humedad 60%',
          lastUpdated: DateTime(2026, 10, 7, 20, 40),
          source: 'https://wttr.in/$city',
          observationTime: '08:40 PM',
          providerArea: '$city, Colombia',
        ),
      );

      final evidence = await context.resolve('¿Qué tiempo hace en Medellín?', []);
      expect(evidence.weatherRequested, isTrue);
      expect(evidence.weatherAvailable, isTrue);
      expect(evidence.block, contains('Ciudad consultada: Medellín'));
      expect(evidence.block, contains('Soleado; 24 °C'));
    });
  });
}
