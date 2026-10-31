// business_library_header.dart
//
// QUÉ HACE:
// Encabezado iOS adaptable de la biblioteca comercial y catálogo.
// Muestra acciones contextuales según la sección activa (Archivos vs Tienda).
//
// CÓMO FUNCIONA:
// - En modo Documentos: ofrece botones para 'Nueva carpeta' e 'Importar'.
// - En modo Tienda: botón '+' esmeralda para nuevo producto y subtítulo dinámico.
//
// POR QUÉ:
// Mantiene coherencia visual y evita saturación de controles (< 175 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'whatsapp_media_library.dart';

class BusinessLibraryHeader extends StatelessWidget {
  final bool isDark;
  final bool isChatPicker;
  final bool isStore;
  final int productsCount;
  final VoidCallback onCreateFolder;
  final VoidCallback onImport;
  final VoidCallback? onAddProduct;
  final VoidCallback onClose;

  const BusinessLibraryHeader({
    super.key,
    required this.isDark,
    required this.isChatPicker,
    this.isStore = false,
    this.productsCount = 0,
    required this.onCreateFolder,
    required this.onImport,
    this.onAddProduct,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final compact = constraints.maxWidth < 430;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _glyph(colors),
                const SizedBox(width: 10),
                Expanded(child: _titleBlock(compact, colors)),
                if (!compact && !isStore) ...[
                  _btn(colors, CupertinoIcons.folder_badge_plus, 'Nueva carpeta', onCreateFolder),
                  const SizedBox(width: 6),
                  _btn(colors, CupertinoIcons.cloud_upload, 'Importar', onImport),
                  const SizedBox(width: 6),
                ],
                if (!isStore)
                  IconButton(
                    tooltip: 'Multimedia autorizada de WhatsApp',
                    onPressed: () => WhatsAppMediaLibrary.show(context),
                    icon: Icon(Icons.perm_media_outlined, color: colors.onSurfaceVariant),
                  ),
                if (isStore && onAddProduct != null) ...[
                  _addButton(colors, onAddProduct!),
                  const SizedBox(width: 6),
                ],
                _closeButton(colors),
              ],
            ),
            if (compact && !isStore) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _btn(colors, CupertinoIcons.folder_badge_plus, 'Nueva carpeta', onCreateFolder)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn(colors, CupertinoIcons.cloud_upload, 'Importar archivos', onImport)),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _glyph(ColorScheme colors) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: isDark ? .18 : .10),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(isStore ? CupertinoIcons.bag_fill : CupertinoIcons.book, color: colors.primary, size: 20),
  );

  Widget _titleBlock(bool compact, ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        isStore ? 'Catálogo y tienda' : 'Biblioteca',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurface, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      ),
      const SizedBox(height: 1.5),
      Text(
        isStore
            ? (isChatPicker
                  ? 'Selecciona productos para enviar'
                  : '$productsCount ${productsCount == 1 ? 'producto' : 'productos'} · Inventario actualizado')
            : (isChatPicker ? 'Selecciona archivos para enviar' : 'Carpetas y documentos para compartir'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
    ],
  );

  Widget _addButton(ColorScheme colors, VoidCallback onTap) => CupertinoButton(
    onPressed: onTap,
    minimumSize: const Size.square(34),
    padding: EdgeInsets.zero,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981), // Verde esmeralda sobrio
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(CupertinoIcons.plus, size: 18, color: Colors.white),
    ),
  );

  Widget _btn(ColorScheme colors, IconData icon, String label, VoidCallback onTap) => CupertinoButton(
    onPressed: onTap,
    minimumSize: const Size.square(34),
    padding: EdgeInsets.zero,
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _closeButton(ColorScheme colors) => CupertinoButton(
    onPressed: onClose,
    minimumSize: const Size.square(34),
    padding: EdgeInsets.zero,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: colors.surfaceContainerHighest.withValues(alpha: .4), shape: BoxShape.circle),
      child: Icon(CupertinoIcons.xmark, size: 14, color: colors.onSurface),
    ),
  );
}
