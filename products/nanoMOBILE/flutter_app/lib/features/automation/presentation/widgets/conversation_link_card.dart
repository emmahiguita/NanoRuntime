// conversation_link_card.dart
// QUÉ HACE: Tarjeta enriquecida Liquid Glass conectada al tema real del sistema (< 160 líneas).
// CÓMO FUNCIONA: Consulta metadatos OpenGraph vía LinkMetadataService y renderiza una tarjeta translúcida con previsualización.
// POR QUÉ: Conecta la paleta cromática con AutomationVisualPalette para armonizar con el tema global.
library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'link_metadata_service.dart';
import 'conversation_media_viewer.dart';
import 'conversation_link_footer.dart';

/// Tarjeta enriquecida translúcida para enlaces web.
class ConversationLinkCard extends StatelessWidget {
  final String url;
  const ConversationLinkCard({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkMetadata>(
      future: LinkMetadataService.fetchMetadata(url),
      builder: (ctx, snapshot) {
        final metadata =
            snapshot.data ??
            LinkMetadataService.getCached(url) ??
            LinkMetadata(
              url: url,
              siteName: Uri.tryParse(url)?.host.replaceFirst('www.', ''),
            );
        return _renderCard(context, metadata);
      },
    );
  }

  Widget _renderCard(BuildContext context, LinkMetadata metadata) {
    final visual = AutomationVisual.of(context);
    final domain = metadata.siteName?.isNotEmpty == true
        ? metadata.siteName!
        : (Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url);
    final hasImg = metadata.imageUrl != null && metadata.imageUrl!.isNotEmpty;
    final hasTitle = metadata.title != null && metadata.title!.isNotEmpty;
    final hasDesc =
        metadata.description != null && metadata.description!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: visual.isDark
            ? visual.cardStart.withValues(alpha: 0.35)
            : visual.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: visual.line,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.shadow.withValues(
              alpha: visual.isDark ? 0.22 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                onTap: () => ConversationMediaViewer.openInAppWeb(
                  context,
                  url,
                  title: domain,
                ),
                child: SizedBox(
                  height: 125,
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
                      Icon(
                        Icons.link_rounded,
                        color: visual.accent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          domain,
                          style: TextStyle(
                            color: visual.accent,
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
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (hasDesc) ...[
                    const SizedBox(height: 3),
                    Text(
                      metadata.description!,
                      style: TextStyle(
                        color: visual.textMuted,
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 7),
                  ConversationLinkFooter(url: url, domain: domain),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
