import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/features/automation/engine/mcp/http_mcp_client.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_connection_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'negotiates session, lists SSE tools and calls them with secure headers',
    () async {
      const sessionId = 'session-test-123';
      const token = 'Bearer runtime-only-token';
      final receivedMethods = <String>[];
      final receivedHeaders = <Map<String, String>>[];
      final httpClient = MockClient((request) async {
        receivedHeaders.add(request.headers);
        if (request.method == 'DELETE') {
          return http.Response('', 405);
        }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final method = payload['method'] as String;
        receivedMethods.add(method);
        if (method == 'initialize') {
          expect(request.headers['authorization'], token);
          expect(request.headers['mcp-session-id'], isNull);
          expect(request.headers['mcp-protocol-version'], isNull);
          expect(payload['params']['protocolVersion'], '2025-11-25');
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': {
                'protocolVersion': '2025-11-25',
                'capabilities': {'tools': {}},
                'serverInfo': {'name': 'test', 'version': '1'},
              },
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'mcp-session-id': sessionId,
            },
          );
        }
        expect(request.headers['mcp-session-id'], sessionId);
        expect(request.headers['mcp-protocol-version'], '2025-11-25');
        if (method == 'notifications/initialized') {
          return http.Response('', 202);
        }
        if (method == 'tools/list') {
          return http.Response(
            'event: message\ndata: ${jsonEncode({
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': {
                'tools': [
                  {
                    'name': 'suggest_dialogue',
                    'description': 'Genera una propuesta sin aplicarla.',
                    'inputSchema': {'type': 'object'},
                  },
                  {
                    'name': 'search_knowledge',
                    'description': 'Consulta conocimiento con una pregunta.',
                    'inputSchema': {
                      'type': 'object',
                      'properties': {
                        'query': {'type': 'string'},
                      },
                      'required': ['query'],
                    },
                    'annotations': {'readOnlyHint': true, 'destructiveHint': false},
                  },
                ],
              },
            })}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        if (method == 'tools/call') {
          expect(payload['params']['name'], 'suggest_dialogue');
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': {
                'content': [
                  {'type': 'text', 'text': 'Propuesta pendiente de revisión.'},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('unexpected method', 400);
      });
      final client = HttpMcpClient(
        descriptor: const McpServerDescriptor(
          id: 'mcp-test',
          displayName: 'MCP de prueba',
          transport: McpTransportKind.streamableHttp,
          endpoint: 'https://mcp.example.test/mcp',
          credentialRef: 'opaque-secure-reference',
        ),
        credentialToken: token,
        httpClient: httpClient,
      );

      final connection = await client.connect();
      final tools = await client.listTools();
      final result = await client.callTool(
        const McpToolCall(serverId: 'mcp-test', toolName: 'suggest_dialogue'),
      );
      await client.disconnect();

      expect(connection.success, isTrue);
      expect(connection.protocolVersion, '2025-11-25');
      expect(tools.map((tool) => tool.name), [
        'suggest_dialogue',
        'search_knowledge',
      ]);
      expect(tools.first.annotations.readOnlyHint, isFalse);
      expect(tools.last.annotations.readOnlyHint, isTrue);
      expect(result.success, isTrue);
      expect(result.content.single.text, 'Propuesta pendiente de revisión.');
      expect(receivedMethods, [
        'initialize',
        'notifications/initialized',
        'tools/list',
        'tools/call',
      ]);
      expect(
        receivedHeaders.every((headers) => headers['authorization'] == token),
        isTrue,
      );
    },
  );

  test(
    'reports HTTP tools/list failures instead of returning an empty catalog',
    () async {
      final httpClient = MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final method = payload['method'] as String;
        if (method == 'initialize') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': payload['id'],
              'result': {
                'protocolVersion': '2025-11-25',
                'capabilities': {'tools': {}},
                'serverInfo': {'name': 'test', 'version': '1'},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (method == 'notifications/initialized') {
          return http.Response('', 202);
        }
        if (method == 'tools/list') {
          return http.Response('unavailable', 503);
        }
        return http.Response('unexpected method', 400);
      });
      final client = HttpMcpClient(
        descriptor: const McpServerDescriptor(
          id: 'mcp-failing',
          displayName: 'MCP caído',
          transport: McpTransportKind.streamableHttp,
          endpoint: 'https://mcp.example.test/mcp',
        ),
        httpClient: httpClient,
      );

      expect((await client.connect()).success, isTrue);
      await expectLater(
        client.listTools(),
        throwsA(
          isA<McpDiscoveryException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
      expect(client.state, McpConnectionState.failed);

      final registry = McpConnectionRegistry();
      await registry.register(client);
      final snapshot = await registry.refreshTools();
      expect(snapshot.tools, isEmpty);
      expect(snapshot.failures.single.reason, contains('HTTP 503'));
      expect(client.state, McpConnectionState.failed);

      await client.disconnect();
    },
  );
}
