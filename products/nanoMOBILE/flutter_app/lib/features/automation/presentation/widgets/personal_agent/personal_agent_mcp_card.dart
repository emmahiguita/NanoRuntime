import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';

import '../../../engine/agent_dependencies.dart';
import '../../screens/mcp_skills_hub_screen.dart';
import '../settings_tile_components.dart';

/// Estado real y acceso a las capacidades MCP usadas por el agente.
class PersonalAgentMcpCard extends ConsumerWidget {
  const PersonalAgentMcpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(mcpConnectionRegistryProvider);
    final servers = registry.servers.toList();
    final connected = servers
        .where((server) => registry.client(server.id)?.state.name == 'connected')
        .length;
    final tools = registry.lastTools.length;

    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.hub_outlined,
          title: 'Herramientas MCP',
          subtitle: servers.isEmpty
              ? 'Sin servidores configurados'
              : '$connected de ${servers.length} servidores · $tools herramientas disponibles',
          trailing: ValueBadge(
            label: connected > 0 ? 'CONECTADO' : 'REVISAR',
          ),
          onTap: () => Navigator.of(context).push(
            nanoGlassPageRoute<void>(
              builder: (_) => const McpSkillsHubScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
