import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';

/// Acciones de una fila: primarias visibles y secundarias agrupadas sin solapar.
class BusinessLibraryFileActions extends StatelessWidget {
  final BusinessDocument document;
  final ValueChanged<BusinessDocument> onOpen, onShare;
  final ValueChanged<BusinessDocument> onRename, onDelete;

  const BusinessLibraryFileActions({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _icon(
        CupertinoIcons.book,
        'Abrir',
        () => onOpen(document),
        color: const Color(0xFF168BFF),
      ),
      _icon(CupertinoIcons.share, 'Compartir', () => onShare(document)),
      SizedBox(
        width: 32,
        height: 44,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: 'Más acciones',
          icon: const Icon(
            CupertinoIcons.ellipsis,
            size: 18,
            color: Color(0xFFA7B8C9),
          ),
          color: const Color(0xFF172638),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            if (value == 'rename') onRename(document);
            if (value == 'delete') onDelete(document);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'rename',
              child: ListTile(
                dense: true,
                leading: Icon(CupertinoIcons.pencil, size: 18),
                title: Text('Renombrar'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                leading: Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: Colors.redAccent,
                ),
                title: Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _icon(
    IconData icon,
    String tooltip,
    VoidCallback tap, {
    Color color = const Color(0xFFA7B8C9),
  }) => IconButton(
    onPressed: tap,
    tooltip: tooltip,
    icon: Icon(icon, size: 17, color: color),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
  );
}
