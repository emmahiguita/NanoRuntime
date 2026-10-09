import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';

/// Filtra por carpeta; el filtro de formato vive únicamente en la toolbar.
class BusinessLibraryCategoryFilters extends StatelessWidget {
  final List<BusinessFolderInfo> folders;
  final String selectedCategory;
  final int allDocumentsCount;
  final ValueChanged<String> onCategory;
  final VoidCallback onShowFolders, onShowRecent;

  const BusinessLibraryCategoryFilters({
    super.key,
    required this.folders,
    required this.selectedCategory,
    required this.allDocumentsCount,
    required this.onCategory,
    required this.onShowFolders,
    required this.onShowRecent,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
      children: [
        _pill(
          'Todos ($allDocumentsCount)',
          selectedCategory == BusinessDocumentLibrary.allCategory,
          () => onCategory(BusinessDocumentLibrary.allCategory),
        ),
        _pill('Carpetas (${folders.length})', false, onShowFolders),
        for (final folder in folders.take(4))
          _pill(
            '${_title(folder.name)} (${folder.itemCount})',
            selectedCategory.toLowerCase() == folder.name.toLowerCase(),
            () => onCategory(folder.name),
          ),
        _pill('Recientes', false, onShowRecent),
      ],
    ),
  );

  Widget _pill(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: Material(
      color: selected ? const Color(0xFF087BFF) : const Color(0xA6172638),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? const Color(0xFF55A7FF)
              : Colors.white.withValues(alpha: .10),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFC5D0E0),
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );

  String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
