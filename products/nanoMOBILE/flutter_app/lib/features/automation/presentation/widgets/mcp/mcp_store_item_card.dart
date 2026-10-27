part of 'mcp_store_components.dart';

/// Tienda MCP: item_card; conserva validación y almacenamiento seguro.
/// Tarjeta visual para un servidor MCP o Skill disponible en la tienda.
class McpStoreItemCard extends StatelessWidget {
  const McpStoreItemCard({
    super.key,
    required this.item,
    required this.visual,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final McpStoreItem item;
  final AutomationVisualPalette visual;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final isRemoteTemplate = item.transport == McpTransportKind.streamableHttp;
    final stateColor = isConnected ? visual.success : visual.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: visual.cardStart,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? visual.success.withValues(alpha: 0.5)
              : visual.cardBorder,
          width: isConnected ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metadataRow(stateColor),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: TextStyle(
              color: visual.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: TextStyle(
              color: visual.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (item.sampleTools.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tool in item.sampleTools)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: visual.inputFill,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: visual.cardBorder),
                    ),
                    child: Text(
                      tool,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: visual.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  isConnected
                      ? 'CONECTADO Y ACTIVO'
                      : isRemoteTemplate
                      ? 'PLANTILLA LISTA PARA CONFIGURAR'
                      : 'NO CONECTADO',
                  style: TextStyle(
                    color: isConnected ? visual.success : visual.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isConnected)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onDisconnect,
                  child: const Text(
                    'Desconectar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onConnect,
                  child: Text(
                    isRemoteTemplate ? 'Configurar' : 'Conectar',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
