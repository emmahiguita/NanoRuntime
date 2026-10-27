import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/features/automation/data/media/conversation_link_reader.dart';
import 'package:nanoai/features/automation/data/media/public_link_target.dart';

void main() {
  test('Destinos privados y credenciales no son enlaces públicos', () {
    for (final address in [
      '127.0.0.1',
      '10.0.0.1',
      '192.168.1.1',
      '172.16.0.1',
      '169.254.1.1',
      '::1',
      'fc00::1',
      '::ffff:127.0.0.1',
    ]) {
      expect(
        PublicLinkTarget.publicAddress(InternetAddress(address)),
        isFalse,
        reason: address,
      );
    }
    expect(PublicLinkTarget.publicAddress(InternetAddress('8.8.8.8')), isTrue);
    expect(
      PublicLinkTarget.validUri(Uri.parse('https://user:pass@example.org')),
      isFalse,
    );
  });

  test('Lee cuerpo real, elimina scripts y reutiliza la evidencia', () async {
    var requests = 0;
    final reader = ConversationLinkReader(
      allowed: (_) async => true,
      client: () => MockClient((request) async {
        requests++;
        return http.Response(
          '<html><title>Plan</title><script>NO EJECUTAR</script><p>Almuerzo a las 12:00</p></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      }),
    );
    final result = await reader.read('https://example.org/plan');
    expect(result, contains('Almuerzo a las 12:00'));
    expect(result, isNot(contains('NO EJECUTAR')));
    await reader.read('https://example.org/plan');
    expect(requests, 1);
  });

  test(
    'Revalida redirección: no consulta localhost ni presenta fallos como contenido',
    () async {
      final visited = <String>[];
      final reader = ConversationLinkReader(
        allowed: (uri) async => uri.host == 'example.org',
        client: () => MockClient((request) async {
          visited.add(request.url.host);
          return http.Response(
            '',
            302,
            isRedirect: true,
            headers: {'location': 'http://localhost/private'},
          );
        }),
      );
      expect(
        await reader.read('https://example.org/redirect'),
        contains('destino no público'),
      );
      expect(visited, ['example.org']);
    },
  );
}
