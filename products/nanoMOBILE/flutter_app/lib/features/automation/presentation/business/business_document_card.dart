// Tarjeta de un documento: concentra miniatura, metadatos y acciones de esa fila.
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'pdf_document_thumbnail.dart';

/// Representa solo un PDF real guardado en la biblioteca local de Nano.
final class BusinessDocumentCard extends StatelessWidget {
  const BusinessDocumentCard({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final BusinessDocument document;
  final VoidCallback onOpen, onShare, onDelete;

  // Formatea el tamaño guardado por el sistema para distinguir archivos.
  String _size(int bytes) => bytes < 1048576
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  // La fila completa abre la lectura; acciones secundarias quedan visibles.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = document.modifiedAt.toLocal();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onOpen,
        leading: PdfDocumentThumbnail(
          key: ValueKey(document.file.path),
          document: document,
        ),
        title: Text(
          document.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${document.category}  ·  ${_size(document.sizeBytes)}  ·  ${date.day}/${date.month}/${date.year}',
        ),
        trailing: Wrap(
          spacing: -8,
          children: [
            IconButton(
              tooltip: 'Leer PDF',
              onPressed: onOpen,
              icon: Icon(Icons.menu_book_outlined, color: colors.primary),
            ),
            IconButton(
              tooltip: 'Compartir',
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
