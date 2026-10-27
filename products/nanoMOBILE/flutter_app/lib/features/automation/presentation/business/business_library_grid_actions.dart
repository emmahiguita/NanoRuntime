import 'package:flutter/cupertino.dart';
import 'business_library_style.dart';
import 'business_library_action_menu.dart';
import '../../engine/business/business_document_library.dart';

/// Menú compacto de la cuadrícula con acciones reales en una hoja iOS.
class BusinessLibraryGridActions extends StatelessWidget {
  final BusinessDocument document;
  final ValueChanged<BusinessDocument> onOpen, onShare, onAnalyze, onRename, onDelete;

  const BusinessLibraryGridActions({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onAnalyze,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: () => _show(context),
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    child: Icon(CupertinoIcons.ellipsis, size: 17, color: context.libraryColors.onSurfaceVariant),
  );

  /// Devuelve una clave y llama una sola función para evitar acciones dobles.
  Future<void> _show(BuildContext context) async {
    final action = await showBusinessLibraryMenu(
      context,
      title: document.name,
      options: [
        const BusinessLibraryOption('open', 'Abrir'),
        const BusinessLibraryOption('share', 'Compartir'),
        if (document.isPdf) const BusinessLibraryOption('analyze', 'Analizar productos para Nano'),
        const BusinessLibraryOption('rename', 'Renombrar'),
        const BusinessLibraryOption('delete', 'Eliminar', destructive: true),
      ],
    );
    if (!context.mounted) return;
    if (action == 'open') onOpen(document);
    if (action == 'share') onShare(document);
    if (action == 'analyze') onAnalyze(document);
    if (action == 'rename') onRename(document);
    if (action == 'delete') onDelete(document);
  }
}
