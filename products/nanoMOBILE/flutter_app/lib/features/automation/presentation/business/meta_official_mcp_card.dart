import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Explica la ruta MCP oficial sin confundir OAuth de Meta con llaves Nano.
class MetaOfficialMcpCard extends StatelessWidget {
  const MetaOfficialMcpCard({super.key});

  static const endpoint = 'https://mcp.facebook.com/whatsapp_business_tools';
  static final _documentation = Uri.parse(
    'https://developers.facebook.com/documentation/mcp/whatsapp-business-tools-mcp',
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.verified_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'MCP oficial de Meta · OAuth',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Chip(label: Text('Beta')),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Administra negocios, números, plantillas, mensajes y webhooks. Usa inicio de sesión Meta; no acepta una llave pegada en este formulario.',
        ),
        const SizedBox(height: 8),
        const SelectableText(endpoint, style: TextStyle(fontSize: 12)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () =>
                launchUrl(_documentation, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('Documentación oficial'),
          ),
        ),
      ],
    ),
  );
}
