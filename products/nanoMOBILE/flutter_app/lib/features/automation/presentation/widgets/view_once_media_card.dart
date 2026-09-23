/// Tarjeta Material 3 para medios de WhatsApp marcados como "ver una vez".
///
/// QUÉ HACE: muestra y abre únicamente el archivo exacto asociado al mensaje.
/// CÓMO: valida la ruta de forma asíncrona y deshabilita la acción si falta.
/// POR QUÉ: buscar "el archivo más reciente" podía mostrar contenido ajeno.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'conversation_media_viewer.dart';

final class ViewOnceMediaCard extends StatefulWidget {
  final String? mediaPath;
  final bool isVideo;

  const ViewOnceMediaCard({super.key, this.mediaPath, this.isVideo = false});

  @override
  State<ViewOnceMediaCard> createState() => _ViewOnceMediaCardState();
}

final class _ViewOnceMediaCardState extends State<ViewOnceMediaCard> {
  File? _file;
  late Future<bool> _exists;

  @override
  void initState() {
    super.initState();
    _resolveExactFile();
  }

  @override
  void didUpdateWidget(covariant ViewOnceMediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath) _resolveExactFile();
  }

  /// Conserva una sola consulta de disco por ruta y nunca escanea carpetas.
  void _resolveExactFile() {
    final path = widget.mediaPath?.trim().replaceFirst('file://', '') ?? '';
    _file = path.isEmpty ? null : File(path);
    _exists = _file?.exists() ?? Future<bool>.value(false);
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.orientationOf(context) == Orientation.landscape
        ? 260.0
        : 290.0;
    return FutureBuilder<bool>(
      future: _exists,
      builder: (context, snapshot) {
        final available = snapshot.data == true && _file != null;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Card.filled(
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (available && !widget.isVideo) _buildPreview(context),
                _buildDescription(context, available),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: FilledButton.tonalIcon(
                    onPressed: available ? () => _openExact(context) : null,
                    icon: Icon(
                      widget.isVideo
                          ? Icons.play_circle_outline_rounded
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      available
                          ? (widget.isVideo ? 'Reproducir video' : 'Ver foto')
                          : 'Medio no disponible',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(BuildContext context) {
    return InkWell(
      onTap: () => _openExact(context),
      child: SizedBox(
        height: 128,
        child: Image.file(
          _file!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 32)),
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context, bool available) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: const Text('1'),
      ),
      title: Text(
        widget.isVideo ? 'Video para ver una vez' : 'Foto para ver una vez',
      ),
      subtitle: Text(
        available
            ? 'Archivo exacto asociado a la notificación'
            : 'WhatsApp no expuso un archivo verificable',
      ),
    );
  }

  /// Abre solo la ruta validada; no sustituye evidencia ausente por otro medio.
  void _openExact(BuildContext context) {
    final file = _file;
    if (file == null) return;
    if (widget.isVideo) {
      ConversationMediaViewer.openVideo(
        context,
        file.path,
        title: 'Video para ver una vez',
      );
      return;
    }
    ConversationMediaViewer.showPhotoViewer(context, pathOrUrl: file.path);
  }
}
