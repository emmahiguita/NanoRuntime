// business_3d_file_preview.dart
//
// QUÉ HACE:
// Renderiza la previsualización realista 3D de documentos comerciales (PDF, XLSX, Video, Archivos generales)
// con bordes biselados, resplandor sutil e iconografía distintiva al estilo iOS Files.
//
// CÓMO FUNCIONA:
// - Detecta la extensión del archivo mediante pattern matching.
// - Dibuja una miniatura estructurada en capas con líneas simuladas de texto y etiqueta de extensión.
// - Aplica soporte automático para modo oscuro y claro.
//
// POR QUÉ:
// Separa la representación visual 3D del grid de renderizado (SRP / SOLID) y mantiene el código bajo 100 líneas.

import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';

class Business3dFilePreview extends StatelessWidget {
  final BusinessDocument document;
  final bool isDark;

  const Business3dFilePreview({
    super.key,
    required this.document,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final (accentColor, label, icon) = switch (true) {
      _ when document.isPdf => (const Color(0xFFEF4444), 'PDF', Icons.picture_as_pdf_rounded),
      _ when document.isSheet => (const Color(0xFF10B981), 'XLSX', Icons.table_chart_rounded),
      _ when document.isVideo => (const Color(0xFF8B5CF6), 'VIDEO', Icons.play_circle_fill_rounded),
      _ => (const Color(0xFF38BDF8), 'DOC', Icons.description_rounded),
    };

    return Center(
      child: Container(
        width: 80,
        height: 96,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 26, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 3, width: 42, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 4),
                    Container(height: 3, width: 56, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 4),
                    Container(height: 3, width: 34, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 4),
                    Container(height: 3, width: 48, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 0.6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(color: accentColor, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: 6, left: 8, child: Icon(icon, color: accentColor, size: 14)),
          ],
        ),
      ),
    );
  }
}
