// business_library_folders_carousel.dart
//
// QUÉ HACE:
// Carrusel horizontal de carpetas comerciales con conteo de elementos y menú contextual CRUD.
//
// CÓMO FUNCIONA:
// - Renderiza tarjetas glass de altura adaptativa (100px) para prevenir desbordamientos visuales.
// - Ofrece un PopupMenuButton para abrir, renombrar o eliminar carpetas personalizadas.
//
// POR QUÉ:
// Soluciona el error 'BOTTOM OVERFLOWED' garantizando espacio suficiente en cualquier densidad de pantalla (< 140 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_library_folder_actions.dart';

class BusinessLibraryFoldersCarousel extends StatelessWidget {
  final List<BusinessFolderInfo> folders;
  final bool isDark;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onRenameFolder;
  final ValueChanged<String> onDeleteFolder;

  const BusinessLibraryFoldersCarousel({
    super.key,
    required this.folders,
    required this.isDark,
    required this.onCategory,
    required this.onRenameFolder,
    required this.onDeleteFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        itemCount: folders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final folder = folders[index];
          final color = _folderColor(folder.name);

          return CupertinoButton(
            onPressed: () => onCategory(folder.name),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            child: Container(
              width: 98,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xB51A2A3B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          color: color,
                          size: 22,
                        ),
                      ),
                      BusinessLibraryFolderActions(
                        folderName: folder.name,
                        onOpen: onCategory,
                        onRename: onRenameFolder,
                        onDelete: onDeleteFolder,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _capitalize(folder.name),
                        style: const TextStyle(
                          color: Color(0xFFE8F0F8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${folder.itemCount} elementos',
                        style: const TextStyle(
                          color: Color(0xFF879DB3),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _folderColor(String name) => switch (name.toLowerCase()) {
    'catálogos' || 'catalogos' => const Color(0xFF278CFF),
    'servicios' => const Color(0xFF9B5CF6),
    'clientes' => const Color(0xFF29D58B),
    'imágenes' || 'imagenes' => const Color(0xFFFFC84D),
    _ => const Color(0xFF64748B),
  };

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
