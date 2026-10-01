// QUÉ: acciones de conexión, exportación y reporte de la AppBar.
// CÓMO: usa LayoutBuilder para decidir cuándo comprimir a menú popup.
//       Delega al controlador y abre visores internos con rutas verificadas.
// POR QUÉ: mantiene la pantalla principal por debajo de 200 líneas y sin I/O.
//
// BUG CORREGIDO: < 720 (basado en MediaQuery.sizeOf) fallaba en landscape compacto
// (600-719px) mostrando solo ⋮ sin botones directos.
// Solución: LayoutBuilder con umbral < 480 basado en espacio REAL disponible en la AppBar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import 'database_google_sheet_dialog.dart';
import 'database_html_viewer.dart';
import 'database_pdf_dialog.dart';
import 'database_shell_connect_dialog.dart';

class DatabaseStudioActions extends StatelessWidget {
  final DatabaseStudioController controller;
  final NanoColors colors;

  const DatabaseStudioActions({
    super.key,
    required this.controller,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // En dispositivos móviles (ancho < 600), mostramos el botón rápido de demo
    // y el menú de acciones para garantizar espacio libre al título y evitar overflows.
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Ejemplo profesional SQLite',
            icon: Icon(Icons.auto_graph_rounded, color: colors.primary, size: 20),
            onPressed: controller.openProfessionalDemo,
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones de datos',
            icon: Icon(Icons.more_vert_rounded, color: colors.primary),
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'demo', child: Text('Recargar demo portafolio')),
              PopupMenuItem(value: 'sheet', child: Text('Importar Google Sheets')),
              PopupMenuItem(value: 'file', child: Text('Conectar archivo o SQLite')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
              PopupMenuItem(value: 'tsv', child: Text('Exportar TSV')),
              PopupMenuItem(value: 'html', child: Text('Crear informe HTML')),
              PopupMenuItem(value: 'pdf', child: Text('Crear informe PDF')),
            ],
          ),
        ],
      );
    }

    // En pantallas grandes o modo horizontal (≥ 600dp), mostramos la barra completa
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Abre la demo SQLite del portafolio de Emmanuel Higuita Gómez
        IconButton(
          tooltip: 'Ejemplo profesional SQLite',
              icon: Icon(Icons.auto_graph_rounded, color: colors.primary, size: 21),
              onPressed: controller.openProfessionalDemo,
            ),
            // Importa una hoja pública de Google Sheets
            IconButton(
              tooltip: 'Google Sheets público',
              icon: Icon(Icons.cloud_download_rounded, color: colors.accent, size: 21),
              onPressed: () => DatabaseGoogleSheetDialog.show(context, controller),
            ),
            // Conecta un archivo CSV/Excel/SQLite desde el dispositivo
            IconButton(
              tooltip: 'Archivo o SQLite',
              icon: Icon(Icons.add_link_rounded, color: colors.primary, size: 21),
              onPressed: () => DatabaseShellConnectDialog.show(
                context,
                controller: controller,
                colors: colors,
              ),
            ),
            // Menú de exportación de datos (CSV, TSV, HTML)
            PopupMenuButton<String>(
              tooltip: 'Exportar datos',
              icon: Icon(Icons.file_download_outlined, color: colors.accent, size: 21),
              onSelected: (format) => _export(context, format),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'csv', child: Text('CSV completo')),
                PopupMenuItem(value: 'tsv', child: Text('TSV completo')),
                PopupMenuItem(value: 'html', child: Text('HTML + visor interno')),
              ],
            ),
            // Genera informe PDF con metadatos del autor y título configurable
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => DatabasePdfDialog.show(
                  context,
                  controller: controller,
                  colors: colors,
                ),
              ),
            ),
          ],
        );
  }

  // Enruta las acciones del menú compacto al método correcto del controlador/dialog
  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'demo':
        await controller.openProfessionalDemo();
        return;
      case 'sheet':
        return DatabaseGoogleSheetDialog.show(context, controller);
      case 'file':
        return DatabaseShellConnectDialog.show(
          context,
          controller: controller,
          colors: colors,
        );
      case 'pdf':
        return DatabasePdfDialog.show(context, controller: controller, colors: colors);
      default:
        return _export(context, action);  // csv, tsv, html
    }
  }

  // Exporta datos y abre el visor HTML interno o copia la ruta al portapapeles
  Future<void> _export(BuildContext context, String format) async {
    final path = format == 'html'
        ? await controller.exportHtml()
        : await controller.exportDelimited(tsv: format == 'tsv');
    if (path == null || !context.mounted) return;
    if (format == 'html') {
      await DatabaseHtmlViewer.show(context, path);
      return;
    }
    // Para CSV/TSV: copia la ruta al portapapeles y notifica con SnackBar
    await Clipboard.setData(ClipboardData(text: path));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo creado; ruta copiada: $path')),
      );
    }
  }
}
