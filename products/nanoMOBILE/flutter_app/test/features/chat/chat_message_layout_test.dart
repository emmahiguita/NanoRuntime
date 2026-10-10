import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/chat/presentation/widgets/chat_messages.dart';
import 'package:nanoai/features/chat/presentation/widgets/nano_rich_weather_card.dart';
import 'package:nanoai/features/chat/presentation/widgets/nano_siata_radar_card.dart';

void main() {
  test('weather card only exists when the response contains real values', () {
    expect(
      NanoRichWeatherCard.parse(
        'En Medellín el clima suele estar entre 18°C y 25°C con humedad alta.',
      ),
      isNull,
    );

    final data = NanoRichWeatherCard.parse(
      'La temperatura actual es 18°C, hay lluvia y humedad del 82%.',
    );
    expect(data?.temperature, '18°C');
    expect(data?.humidity, 'Humedad 82%');
  });

  test('SIATA card is limited to rain questions about its coverage area', () {
    expect(
      NanoSiataRadarCard.shouldShow('¿Está lloviendo en Medellín?'),
      isTrue,
    );
    expect(
      NanoSiataRadarCard.shouldShow('¿Está lloviendo en Bogotá?'),
      isFalse,
    );
  });

  testWidgets('assistant weather response keeps readable width on a phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: MessageBubble(
                text:
                    'En Medellín la temperatura actual es 18°C. Hay lluvia moderada y humedad del 82%.',
                isUser: false,
                model: 'Gemma local',
                timestamp: DateTime(2026, 10, 9, 10, 30),
                source: MessageSource.model,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('18°C'), findsOneWidget);
    expect(find.text('Humedad 82%'), findsOneWidget);
    expect(find.text('Radar SIATA en vivo'), findsOneWidget);
  });
}
