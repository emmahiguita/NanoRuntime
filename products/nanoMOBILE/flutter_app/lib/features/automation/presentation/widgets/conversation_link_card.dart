// conversation_link_card.dart
//
// QUÉ HACE:
// Tarjeta enriquecida para enlaces y URLs recibidos en mensajes de chat.
//
// CÓMO FUNCIONA:
// - Consulta metadatos OpenGraph (título, descripción, imagen y dominio) vía LinkMetadataService.
// - Renderiza una tarjeta elegante con imagen de cabecera y botón de navegación in-app.
//
// POR QUÉ:
// Responsabilidad única (SRP) para enlaces web, estrictamente < 200 líneas.

library;

import 'package:flutter/material.dart';
import 'link_metadata_service.dart';
import 'conversation_media_viewer.dart';

/// Tarjeta enriquecida para enlaces web.
class ConversationLinkCard extends StatelessWidget {
  final String url;
  const ConversationLinkCard({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkMetadata>(
      future: LinkMetadataService.fetchMetadata(url),
      builder: (ctx, snapshot) {
        final metadata = snapshot.data ??
            LinkMetadataService.getCached(url) ??
            LinkMetadata(url: url, siteName: Uri.tryParse(url)?.host.replaceFirst('www.', ''));
        return _renderCard(context, metadata);
      },
    );
  }

  Widget _renderCard(BuildContext context, LinkMetadata metadata) {
    final domain = metadata.siteName?.isNotEmpty == true
        ? metadata.siteName!
        : (Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url);
    final hasImg = metadata.imageUrl != null && metadata.imageUrl!.isNotEmpty;
    final hasTitle = metadata.title != null && metadata.title!.isNotEmpty;
    final hasDesc = metadata.description != null && metadata.description!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 0.9),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImg)
              GestureDetector(
                onTap: () => ConversationMediaViewer.openInAppWeb(context, url, title: domain),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: Image.network(
                    metadata.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Color(0xFF38BDF8), size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          domain,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (hasTitle) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata.title!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (hasDesc) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata.description!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => ConversationMediaViewer.openInAppWeb(context, url, title: domain),
                          child: Text(
                            url,
                            style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, decoration: TextDecoration.underline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => ConversationMediaViewer.openInAppWeb(context, url, title: domain),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 0.6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_browser_rounded, color: Color(0xFF93C5FD), size: 12),
                              SizedBox(width: 3),
                              Text('Abrir', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
