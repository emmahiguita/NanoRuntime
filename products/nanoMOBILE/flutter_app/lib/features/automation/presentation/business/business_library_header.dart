// business_library_header.dart
//
// QUÉ HACE:
// Barra superior con diseño iOS Frosted Glass para la biblioteca de documentos comerciales de Nano.
//
// CÓMO FUNCIONA:
// - Despliega el título principal 'Biblioteca' y subtítulo conciso sin truncamientos.
// - Incluye botones de acción rápida (+ Carpeta, Importar y Cerrar) con estética translúcida.
//
// POR QUÉ:
// Asegura una lectura limpia y profesional en todas las resoluciones móviles (< 120 líneas).

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF168BFF),
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Biblioteca',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  isChatPicker
                      ? 'Selecciona archivos para enviar'
                      : 'Organiza carpetas, catálogos y archivos para enviar.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _actionButton(
            Icons.create_new_folder_outlined,
            'Nueva carpeta',
            onCreateFolder,
          ),
          const SizedBox(width: 5),
          _actionButton(Icons.cloud_upload_outlined, 'Importar', onImport),
          const SizedBox(width: 5),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFF223247),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFFB3C2D1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xB51B2A3E),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFFBBD0E4)),
            const SizedBox(width: 3.5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD7E2ED),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
