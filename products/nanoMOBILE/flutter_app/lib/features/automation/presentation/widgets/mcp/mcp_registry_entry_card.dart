import 'package:flutter/material.dart';

import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_registry_catalog_source.dart';
import '../../../engine/mcp/mcp_store_catalog.dart';
import '../../automation_visual_theme.dart';

/// Muestra la ficha del registro y habilita solo endpoints compatibles con Nano.
class McpRegistryEntryCard extends StatelessWidget {
  const McpRegistryEntryCard({
    super.key,
    required this.entry,
    required this.visual,
    required this.onConnect,
  });

  final McpRegistryEntry entry;
  final AutomationVisualPalette visual;
  final ValueChanged<McpStoreItem> onConnect;

  @override
  Widget build(BuildContext context) {
    final remote = entry.nanoConnectableRemote;
    return Card(
      color: visual.cardStart,
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: visual.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: TextStyle(
                color: visual.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${entry.name} · v${entry.version}',
              style: TextStyle(color: visual.textMuted, fontSize: 12),
            ),
            if (entry.repositoryUrl.isNotEmpty)
              SelectableText(
                'Repositorio: ${entry.repositoryUrl}',
                style: TextStyle(color: visual.accent, fontSize: 12),
                maxLines: 2,
              ),
            const SizedBox(height: 7),
            Text(
              entry.description,
              style: TextStyle(color: visual.text, fontSize: 13, height: 1.35),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              remote == null
                  ? 'Ficha informativa · requiere runtime, variables o transporte no compatible.'
                  : 'Endpoint HTTPS Streamable HTTP publicado · revisa el servidor antes de conectar.',
              style: TextStyle(
                color: visual.textMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            if (entry.packageTypes.isNotEmpty)
              Text(
                'Paquetes: ${entry.packageTypes.join(', ')}',
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
            if (remote != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onConnect(
                    McpStoreItem(
                      id: _registryEntryId(entry.name),
                      name: entry.title,
                      author: 'MCP Registry',
                      category: McpStoreCategory.developer,
                      description: entry.description,
                      repositoryUrl: entry.repositoryUrl,
                      defaultEndpoint: remote.url,
                      transport: McpTransportKind.streamableHttp,
                      tags: const ['registro público', 'streamable-http'],
                    ),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Configurar conexión'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Forma un ID estable y sin caracteres reservados para guardar el servidor localmente.
String _registryEntryId(String name) {
  var hash = 0x811c9dc5;
  for (final unit in name.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  final slug = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  final shortSlug = slug.length > 54 ? slug.substring(0, 54) : slug;
  return 'registry-$shortSlug-${hash.toRadixString(16)}';
}
