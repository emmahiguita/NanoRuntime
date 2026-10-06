// Vista de biblioteca: separa el diseño adaptable de las operaciones con archivos.
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_document_card.dart';
import 'business_library_load_error.dart';

/// Presenta PDFs reales por carpeta con búsqueda, lectura y acciones directas.
final class BusinessDocumentLibraryView extends StatelessWidget {
  const BusinessDocumentLibraryView({
    super.key,
    required this.title,
    required this.category,
    required this.query,
    required this.documents,
    required this.loadError,
    required this.busy,
    required this.canGenerate,
    required this.onCategory,
    required this.onQuery,
    required this.onImport,
    required this.onGenerate,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
    required this.onClose,
    required this.onRetry,
  });

  final String title, category, query;
  final List<BusinessDocument> documents;
  final String? loadError;
  final bool busy, canGenerate;
  final ValueChanged<String> onCategory, onQuery;
  final VoidCallback onImport, onGenerate, onClose;
  final VoidCallback onRetry;
  final ValueChanged<BusinessDocument> onOpen, onShare, onDelete;

  // Construye un lector de biblioteca con controles compactos en orientación estrecha.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biblioteca',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: onQuery,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar documentos',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                for (final folder in [
                  BusinessDocumentLibrary.allCategory,
                  ...BusinessDocumentLibrary.categories,
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(folder),
                      selected: folder == category,
                      onSelected: busy ? null : (_) => onCategory(folder),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onImport,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(compact ? 'Importar' : 'Importar PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy || !canGenerate ? null : onGenerate,
                    icon: const Icon(Icons.add_to_drive_rounded),
                    label: Text(compact ? 'Catálogo' : 'Guardar catálogo'),
                  ),
                ),
              ],
            ),
          ),
          if (!canGenerate)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Añade servicios y precios reales para generar el catálogo.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: loadError != null
                ? BusinessLibraryLoadError(busy: busy, onRetry: onRetry)
                : documents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 42,
                            color: colors.outline,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            query.isEmpty
                                ? 'Esta carpeta está vacía'
                                : 'Sin coincidencias',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Importa un PDF o cambia de carpeta.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                    itemCount: documents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      return BusinessDocumentCard(
                        document: doc,
                        onOpen: () => onOpen(doc),
                        onShare: () => onShare(doc),
                        onDelete: () => onDelete(doc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
