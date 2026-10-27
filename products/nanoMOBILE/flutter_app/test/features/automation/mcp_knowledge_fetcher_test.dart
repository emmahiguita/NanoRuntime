import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/browser/reverse_agent_client.dart';
import 'package:nanoai/features/automation/engine/browser/web_knowledge_service.dart';
import 'package:nanoai/features/automation/engine/conversation/turn_knowledge_fetcher.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_connection_registry.dart';

void main() {
  test(
    'routes only schema-compatible read-only MCP knowledge through caller',
    () async {
      final client = _FakeMcpClient([
        const McpRemoteTool(
          serverId: 'docs',
          name: 'write_document',
          inputSchema: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
        ),
        const McpRemoteTool(
          serverId: 'docs',
          name: 'search_knowledge',
          annotations: McpToolAnnotations(readOnlyHint: true),
          inputSchema: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
              'limit': {'type': 'integer'},
            },
            'required': ['query'],
          },
        ),
        const McpRemoteTool(
          serverId: 'docs',
          name: 'search_admin',
          annotations: McpToolAnnotations(readOnlyHint: true),
          inputSchema: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
              'tenant': {'type': 'string'},
            },
            'required': ['query', 'tenant'],
          },
        ),
      ]);
      final registry = McpConnectionRegistry();
      await registry.register(client);
      McpRemoteTool? invokedTool;
      Map<String, Object?>? invokedArguments;

      final fetcher = TurnKnowledgeFetcher(
        mcpConnectionRegistry: registry,
        mcpKnowledgeToolCaller: (tool, arguments) async {
          invokedTool = tool;
          invokedArguments = arguments;
          return 'Respuesta consultada en MCP.';
        },
        webKnowledgeService: const _NoWebKnowledge(),
        reverseAgentClient: const _NoReverseAgent(),
      );

      final result = await fetcher.executeCascade(
        '¿Qué dice la documentación?',
      );

      expect(result.source, 'mcp_docs_search_knowledge');
      expect(result.rawKnowledge, 'Respuesta consultada en MCP.');
      expect(invokedTool?.name, 'search_knowledge');
      expect(invokedArguments, {'query': '¿Qué dice la documentación?'});
      expect(client.directToolCalls, 0);
    },
  );
}

final class _FakeMcpClient implements McpClientPort {
  _FakeMcpClient(this._tools)
    : descriptor = const McpServerDescriptor(
        id: 'docs',
        displayName: 'Documentación',
        transport: McpTransportKind.streamableHttp,
        endpoint: 'https://mcp.example.test/mcp',
      );

  final List<McpRemoteTool> _tools;
  @override
  final McpServerDescriptor descriptor;
  McpConnectionState _state = McpConnectionState.disconnected;
  int directToolCalls = 0;

  @override
  McpConnectionState get state => _state;

  @override
  Future<McpConnectionResult> connect() async {
    _state = McpConnectionState.connected;
    return const McpConnectionResult(status: McpOperationStatus.success);
  }

  @override
  Future<void> disconnect() async {
    _state = McpConnectionState.disconnected;
  }

  @override
  Future<List<McpRemoteTool>> listTools() async => _tools;

  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    directToolCalls++;
    return const McpToolCallResult(status: McpOperationStatus.failed);
  }
}

final class _NoWebKnowledge extends WebKnowledgeService {
  const _NoWebKnowledge();

  @override
  Future<WebKnowledgeResult> search(String query) async => WebKnowledgeResult(
    query: query,
    title: 'Sin fuentes',
    summary: '',
    found: false,
  );
}

final class _NoReverseAgent extends ReverseAgentClient {
  const _NoReverseAgent();

  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<void> stopBridge() async {}
}
