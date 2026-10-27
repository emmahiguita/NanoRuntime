import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/automation/engine/mcp/http_mcp_client.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_connection_registry.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_server_persistence.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_server_restorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('restorePersistedMcpConnections', () {
    late TestCredentialStore credentials;
    late McpServerPersistence persistence;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      credentials = TestCredentialStore();
      persistence = McpServerPersistence(credentials: credentials);
      await persistence.save(
        McpServerDescriptor(
          id: 'mcp-assistant',
          displayName: 'Cuenta MCP de Automatización',
          transport: McpTransportKind.streamableHttp,
          endpoint: 'https://mcp.example.test/mcp',
          credentialRef: persistence.credentialRefFor('mcp-assistant'),
        ),
        credentialToken: 'server-token',
      );
    });

    test('connects saved server and registers its real tool catalog', () async {
      var toolListCalls = 0;
      final registry = McpConnectionRegistry();
      final report = await restorePersistedMcpConnections(
        registry: registry,
        persistence: persistence,
        createClient: (configuration) => HttpMcpClient(
          descriptor: configuration.descriptor,
          credentialToken: configuration.credentialToken,
          httpClient: MockClient((request) async {
            if (request.method == 'DELETE') return http.Response('', 405);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            switch (body['method']) {
              case 'initialize':
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': body['id'],
                    'result': {
                      'protocolVersion': '2025-11-25',
                      'capabilities': {'tools': {}},
                    },
                  }),
                  200,
                  headers: {
                    'content-type': 'application/json',
                    'mcp-session-id': 'persisted-session',
                  },
                );
              case 'notifications/initialized':
                return http.Response('', 202);
              case 'tools/list':
                toolListCalls++;
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': body['id'],
                    'result': {
                      'tools': [
                        {'name': 'improve_dialogue', 'inputSchema': {}},
                      ],
                    },
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
            }
            return http.Response('', 400);
          }),
        ),
      );

      expect(report.restoredServerIds, ['mcp-assistant']);
      expect(report.failedServerIds, isEmpty);
      expect(report.missingCredentialIds, isEmpty);
      expect(registry.connectedServerIds, {'mcp-assistant'});
      expect(
        registry.lastTools.keys,
        contains('mcp-assistant/improve_dialogue'),
      );
      expect(toolListCalls, 1);

      await registry.unregister('mcp-assistant');
    });

    test('does not connect when the secure credential is missing', () async {
      await credentials.delete(persistence.credentialRefFor('mcp-assistant'));
      final registry = McpConnectionRegistry();
      var factoryCalls = 0;

      final report = await restorePersistedMcpConnections(
        registry: registry,
        persistence: persistence,
        createClient: (_) {
          factoryCalls++;
          throw StateError('must not build a client without its credential');
        },
      );

      expect(report.missingCredentialIds, ['mcp-assistant']);
      expect(factoryCalls, 0);
      expect(registry.connectedServerIds, isEmpty);
    });
  });
}

final class TestCredentialStore implements McpCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}
