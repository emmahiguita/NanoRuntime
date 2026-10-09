// Encabezado iOS adaptable de la biblioteca comercial.
// Separa identidad y acciones en pantallas estrechas para impedir solapamientos.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BusinessLibraryHeader extends StatelessWidget {
  final bool isDark;
  final bool isChatPicker;
  final VoidCallback onCreateFolder;
  final VoidCallback onImport;
  final VoidCallback onClose;

  const BusinessLibraryHeader({
    super.key,
    required this.isDark,
    required this.isChatPicker,
    required this.onCreateFolder,
    required this.onImport,
    required this.onClose,
  });

  /// Cambia a dos niveles cuando los botones ya no caben junto al título.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _libraryGlyph(),
                const SizedBox(width: 10),
                Expanded(child: _titleBlock(compact)),
                if (!compact) ...[
                  _actionButton(
                    CupertinoIcons.folder_badge_plus,
                    'Nueva carpeta',
                    onCreateFolder,
                  ),
                  const SizedBox(width: 6),
                  _actionButton(
                    CupertinoIcons.cloud_upload,
                    'Importar',
                    onImport,
                  ),
                  const SizedBox(width: 6),
                ],
                _closeButton(),
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      CupertinoIcons.folder_badge_plus,
                      'Nueva carpeta',
                      onCreateFolder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      CupertinoIcons.cloud_upload,
                      'Importar archivos',
                      onImport,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  /// Identifica la biblioteca sin competir visualmente con el título.
  Widget _libraryGlyph() => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: const Color(0x261E9BFF),
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Icon(
      CupertinoIcons.book,
      color: Color(0xFF1E9BFF),
      size: 21,
    ),
  );

  /// Establece jerarquía: título de una línea y descripción secundaria.
  Widget _titleBlock(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Biblioteca',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 21,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        isChatPicker
            ? 'Selecciona archivos para enviar'
            : 'Carpetas, catálogos y archivos listos para compartir',
        maxLines: compact ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );

  /// Botón translúcido con área táctil estable y etiqueta no quebrable.
  Widget _actionButton(IconData icon, String label, VoidCallback onTap) =>
      CupertinoButton(
        onPressed: onTap,
        minSize: 36,
        padding: EdgeInsets.zero,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: const Color(0xB51B2A3E),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFFC7D8E8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE0EAF3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// Cierra el modal con el patrón circular de iOS.
  Widget _closeButton() => CupertinoButton(
    onPressed: onClose,
    minSize: 36,
    padding: EdgeInsets.zero,
    child: Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF223247),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        CupertinoIcons.xmark,
        size: 15,
        color: Color(0xFFB8C8D7),
      ),
    ),
  );
}
