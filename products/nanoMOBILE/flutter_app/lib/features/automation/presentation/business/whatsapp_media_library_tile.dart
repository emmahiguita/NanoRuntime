import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../application/whatsapp_media_catalog_client.dart';

/// La celda conserva una sola solicitud de miniatura; el original no se decodifica aquí.
class WhatsAppMediaLibraryTile extends StatefulWidget {
  final Map<String, dynamic> row;
  final WhatsAppMediaCatalogClient client;
  const WhatsAppMediaLibraryTile({
    super.key,
    required this.row,
    required this.client,
  });
  @override
  State<WhatsAppMediaLibraryTile> createState() =>
      _WhatsAppMediaLibraryTileState();
}

class _WhatsAppMediaLibraryTileState extends State<WhatsAppMediaLibraryTile> {
  late final Future<Uint8List?>? _thumbnail = widget.row['kind'] == 'audio'
      ? null
      : widget.client.thumbnail(widget.row);
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.client.open('${widget.row['uri']}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Archivo no disponible o sin aplicación para abrirlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _opening ? null : _open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FutureBuilder<Uint8List?>(
              future: _thumbnail,
              builder: (_, snapshot) {
                final bytes = snapshot.data;
                return bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      )
                    : Icon(
                        widget.row['kind'] == 'audio'
                            ? Icons.audio_file_outlined
                            : Icons.perm_media_outlined,
                      );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.row['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.row['source']} · sin chat vinculado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
