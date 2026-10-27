import 'package:flutter/cupertino.dart';
import 'business_library_style.dart';
import 'business_library_action_menu.dart';
import '../../engine/business/business_document_library.dart';

/// Acciones de una fila: primarias visibles y secundarias agrupadas sin solapar.
class BusinessLibraryFileActions extends StatelessWidget {
  final BusinessDocument document;
  final ValueChanged<BusinessDocument> onOpen, onShare;
  final ValueChanged<BusinessDocument> onRename, onDelete;
  final ValueChanged<BusinessDocument> onAnalyze;

  const BusinessLibraryFileActions({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _icon(context, CupertinoIcons.book, 'Abrir', () => onOpen(document), color: context.libraryColors.primary),
      _icon(context, CupertinoIcons.share, 'Compartir', () => onShare(document)),
      CupertinoButton(
        onPressed: () => _showMore(context),
        minimumSize: const Size.square(44),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Icon(CupertinoIcons.ellipsis, size: 18, color: context.libraryColors.onSurfaceVariant),
      ),
    ],
  );

  Widget _icon(BuildContext context, IconData icon, String tooltip, VoidCallback tap, {Color? color}) => Semantics(
    label: tooltip,
    button: true,
    child: CupertinoButton(
      onPressed: tap,
      minimumSize: const Size.square(44),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Icon(icon, size: 17, color: color ?? context.libraryColors.onSurfaceVariant),
    ),
  );

  /// Devuelve la elección desde un menú flotante; cerrar no ejecuta acciones.
  Future<void> _showMore(BuildContext context) async {
    final action = await showBusinessLibraryMenu(
      context,
      title: document.name,
      options: [
        if (document.isPdf) const BusinessLibraryOption('analyze', 'Analizar productos para Nano'),
        const BusinessLibraryOption('rename', 'Renombrar'),
        const BusinessLibraryOption('delete', 'Eliminar', destructive: true),
      ],
    );
    if (!context.mounted) return;
    if (action == 'rename') onRename(document);
    if (action == 'analyze') onAnalyze(document);
    if (action == 'delete') onDelete(document);
  }
}
