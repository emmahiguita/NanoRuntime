import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';

void main() {
  test(
    'RuntimeStatus conserva temperatura real y sensor ausente como null',
    () {
      final measured = RuntimeStatus.fromJson({'temperature_c': 43.25});
      final unavailable = RuntimeStatus.fromJson({});

      expect(measured.temperatureC, 43.25);
      expect(unavailable.temperatureC, isNull);
    },
  );

  test(
    'assessModelViability usa el veredicto Rust sin umbrales Dart',
    () async {
      late http.Request captured;
      final client = LLMEngineClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'tier': 'RECOMMENDED',
              'can_run': true,
              'should_run_interactive': true,
              'reason': 'fits measured budget',
            }),
            200,
          );
        }),
      );

      final verdict = await client.assessModelViability(1_073_741_824);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/viability');
      expect(jsonDecode(captured.body)['model_size_bytes'], 1_073_741_824);
      expect(verdict.tier, 'RECOMMENDED');
      expect(verdict.canRun, isTrue);
      expect(verdict.shouldRunInteractive, isTrue);
    },
  );

  test(
    'assessModelViability rechaza tamaños no físicos antes de HTTP',
    () async {
      final client = LLMEngineClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => client.assessModelViability(0),
        throwsA(isA<LLMEngineException>()),
      );
    },
  );
}
