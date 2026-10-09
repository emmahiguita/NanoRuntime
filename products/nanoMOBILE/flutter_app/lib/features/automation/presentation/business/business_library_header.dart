// business_library_header.dart
//
// QUÉ HACE:
// Encabezado iOS adaptable de la biblioteca comercial.
// Muestra acciones contextuales según la sección activa (Archivos vs Tienda).
//
// CÓMO FUNCIONA:
// - En modo Documentos: ofrece botones para 'Nueva carpeta' e 'Importar'.
// - En modo Tienda: ofrece botón para 'Nuevo producto' y subtítulo comercial.
//
// POR QUÉ:
// Mantiene coherencia visual y evita saturación de controles (< 175 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BusinessLibraryHeader extends StatelessWidget {
  final bool isDark;
  final bool isChatPicker;
  final bool isStore;
  final VoidCallback onCreateFolder;
  final VoidCallback onImport;
  final VoidCallback? onAddProduct;
  final VoidCallback onClose;

  const BusinessLibraryHeader({
    super.key,
    required this.isDark,
    required this.isChatPicker,
    this.isStore = false,
    required this.onCreateFolder,
    required this.onImport,
    this.onAddProduct,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _glyph(),
                const SizedBox(width: 10),
                Expanded(child: _titleBlock(compact)),
                if (!compact && !isStore) ...[
                  _btn(CupertinoIcons.folder_badge_plus, 'Nueva carpeta', onCreateFolder),
                  const SizedBox(width: 6),
                  _btn(CupertinoIcons.cloud_upload, 'Importar', onImport),
                  const SizedBox(width: 6),
                ],
                _closeButton(),
              ],
            ),
            if (compact && !isStore) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _btn(CupertinoIcons.folder_badge_plus, 'Nueva carpeta', onCreateFolder)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn(CupertinoIcons.cloud_upload, 'Importar archivos', onImport)),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _glyph() => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: isStore ? const Color(0x26087BFF) : const Color(0x261E9BFF),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(
      isStore ? CupertinoIcons.bag_fill : CupertinoIcons.book,
      color: const Color(0xFF1E9BFF),
      size: 20,
    ),
  );

  Widget _titleBlock(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        isStore ? 'Catálogo & Tienda' : 'Biblioteca',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        isStore
            ? (isChatPicker ? 'Selecciona productos para enviar' : 'Inventario, precios y stock sincronizados con tu IA')
            : (isChatPicker ? 'Selecciona archivos para enviar' : 'Carpetas y documentos para compartir'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );

  Widget _btn(IconData icon, String label, VoidCallback onTap) => CupertinoButton(
    onPressed: onTap,
    minimumSize: const Size.square(34),
    padding: EdgeInsets.zero,
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xB51B2A3E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFC7D8E8)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFE0EAF3), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _closeButton() => CupertinoButton(
    onPressed: onClose,
    minimumSize: const Size.square(34),
    padding: EdgeInsets.zero,
    child: Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Color(0xFF223247), shape: BoxShape.circle),
      child: const Icon(CupertinoIcons.xmark, size: 14, color: Color(0xFFB8C8D7)),
    ),
  );
}
