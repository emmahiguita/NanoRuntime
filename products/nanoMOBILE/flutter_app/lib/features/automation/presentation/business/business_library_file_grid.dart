import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_library_grid_card.dart';

/// Cuadrícula adaptable; solo decide distribución y delega cada tarjeta.
class BusinessLibraryFileGrid extends StatelessWidget {
  final List<BusinessDocument> documents;
  final Set<String> selectedPaths;
  final bool isSelectionMode, isDark;
  final ValueChanged<BusinessDocument> onSelectDocument, onOpen, onShare;
  final ValueChanged<BusinessDocument> onRenameDocument, onDeleteDocument;

  const BusinessLibraryFileGrid({
    super.key,
    required this.documents,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.isDark,
    required this.onSelectDocument,
    required this.onOpen,
    required this.onShare,
    required this.onRenameDocument,
    required this.onDeleteDocument,
  });

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    sliver: SliverGrid.builder(
      // El ancho máximo agrega columnas en horizontal sin estirar tarjetas.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisExtent: 190,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: documents.length,
      itemBuilder: (_, index) {
        final document = documents[index];
        return BusinessLibraryGridCard(
          document: document,
          selected: selectedPaths.contains(document.file.path),
          isSelectionMode: isSelectionMode,
          isDark: isDark,
          onSelect: onSelectDocument,
          onOpen: onOpen,
          onShare: onShare,
          onRename: onRenameDocument,
          onDelete: onDeleteDocument,
        );
      },
    ),
  );
}
