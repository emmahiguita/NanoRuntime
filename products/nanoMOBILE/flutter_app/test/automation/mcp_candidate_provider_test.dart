import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_candidate_provider.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_provider.dart';

void main() {
  const adapter = McpToolAdapter();

  test('read tool matcheada → candidate mcp grounded', () async {
    const registry = McpToolRegistry({
      'read_file': McpTool(
        id: 'read_file',
        name: 'read_file',
        category: McpToolCategory.read,
      ),
      'list_dir': McpTool(
        id: 'list_dir',
        name: 'list_dir',
        category: McpToolCategory.read,
      ),
    });
    final provider = McpCandidateProvider(registry, adapter);
    final candidates = await provider.provide(
      const CandidateRequest('lee el archivo con read_file'),
    );
    expect(candidates, hasLength(1));
    expect(candidates.single.channel, ActionChannel.mcp);
    expect(candidates.single.tool, 'mcp.read');
  });

  test('registry vacío → sin candidates', () async {
    final provider = McpCandidateProvider(const McpToolRegistry(), adapter);
    expect(
      await provider.provide(const CandidateRequest('read_file')),
      isEmpty,
    );
  });

  test('externalWrite/privileged NO se exponen como candidates', () async {
    const registry = McpToolRegistry({
      'send_msg': McpTool(
        id: 'send_msg',
        name: 'send_msg',
        category: McpToolCategory.externalWrite,
      ),
      'admin': McpTool(
        id: 'admin',
        name: 'admin',
        category: McpToolCategory.privileged,
      ),
      'read_file': McpTool(
        id: 'read_file',
        name: 'read_file',
        category: McpToolCategory.read,
      ),
    });
    final provider = McpCandidateProvider(registry, adapter);
    final candidates = await provider.provide(
      const CandidateRequest('send_msg admin read_file'),
    );
    // Solo read_file (read) se expone; externalWrite/privileged no.
    expect(candidates, hasLength(1));
    expect(candidates.single.tool, 'mcp.read');
  });
}
