// database_studio_actions.dart
//
// QUÉ HACE:
// Acciones de conexión, exportación, sincronización en vivo y reportes en la AppBar.
//
// CÓMO FUNCIONA:
// - Adapta los controles según el ancho de pantalla (modo compacto vs extendido).
// - Provee acceso en 1 toque a la auto-conexión y sincronización en tiempo real de Google Sheets.
// - Renderiza insignia viva cuando la sincronización está activa.
//
// POR QUÉ:
// Aplica SOLID (SRP) manteniendo la barra de acciones modular, responsiva
// y sin lógica pesada de I/O (< 200 líneas).

library;

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
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final isLive = controller.currentState.isLiveSyncActive;

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Ejemplo profesional SQLite',
            icon: Icon(
              Icons.auto_graph_rounded,
              color: colors.primary,
              size: 20,
            ),
            onPressed: controller.openProfessionalDemo,
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones de datos',
            icon: Icon(Icons.more_vert_rounded, color: colors.primary),
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'auto_sheet',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 8),
                    Text('⚡ Auto-conectar Sheets (En vivo)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sheet',
                child: Text('Configurar Google Sheets'),
              ),
              if (controller.currentState.currentTable?.isGoogleSheet == true)
                const PopupMenuItem(
                  value: 'sync_now',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 8),
                      Text('Sincronizar Sheets ahora'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Espacio en blanco (Sin base demo)'),
              ),
              const PopupMenuItem(
                value: 'demo',
                child: Text('Cargar ejemplo demostración'),
              ),
              const PopupMenuItem(
                value: 'file',
                child: Text('Conectar archivo o SQLite'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
              const PopupMenuItem(value: 'tsv', child: Text('Exportar TSV')),
              const PopupMenuItem(value: 'html', child: Text('Crear informe HTML')),
              const PopupMenuItem(value: 'pdf', child: Text('Crear informe PDF')),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLive)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              avatar: const Icon(
                Icons.sensors_rounded,
                size: 13,
                color: Color(0xFF10B981),
              ),
              label: const Text(
                'En vivo',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
              side: const BorderSide(color: Color(0xFF10B981), width: 0.8),
              onPressed: () => DatabaseGoogleSheetDialog.show(context, controller),
            ),
          ),
        IconButton(
          tooltip: 'Ejemplo profesional SQLite',
          icon: Icon(Icons.auto_graph_rounded, color: colors.primary, size: 21),
          onPressed: controller.openProfessionalDemo,
        ),
        IconButton(
          tooltip: '⚡ Auto-conectar Google Sheets (Tiempo Real)',
          icon: const Icon(
            Icons.bolt_rounded,
            color: Color(0xFF10B981),
            size: 22,
          ),
          onPressed: () => controller.autoConnectGoogleSheets(),
        ),
        IconButton(
          tooltip: 'Configurar Google Sheets',
          icon: Icon(
            Icons.cloud_download_rounded,
            color: colors.accent,
            size: 21,
          ),
          onPressed: () => DatabaseGoogleSheetDialog.show(context, controller),
        ),
        IconButton(
          tooltip: 'Archivo o SQLite',
          icon: Icon(Icons.add_link_rounded, color: colors.primary, size: 21),
          onPressed: () => DatabaseShellConnectDialog.show(
            context,
            controller: controller,
            colors: colors,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Exportar datos',
          icon: Icon(
            Icons.file_download_outlined,
            color: colors.accent,
            size: 21,
          ),
          onSelected: (format) => _export(context, format),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'csv', child: Text('CSV completo')),
            PopupMenuItem(value: 'tsv', child: Text('TSV completo')),
            PopupMenuItem(value: 'html', child: Text('HTML + visor interno')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
            label: const Text(
              'PDF',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
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

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'auto_sheet':
        await controller.autoConnectGoogleSheets();
        return;
      case 'sync_now':
        await controller.syncGoogleSheetsNow();
        return;
      case 'clear':
        controller.clearToBlankDatabase();
        return;
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
        return DatabasePdfDialog.show(
          context,
          controller: controller,
          colors: colors,
        );
      default:
        return _export(context, action);
    }
  }

  Future<void> _export(BuildContext context, String format) async {
    final path = format == 'html'
        ? await controller.exportHtml()
        : await controller.exportDelimited(tsv: format == 'tsv');
    if (path == null || !context.mounted) return;
    if (format == 'html') {
      await DatabaseHtmlViewer.show(context, path);
      return;
    }
    await Clipboard.setData(ClipboardData(text: path));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo creado; ruta copiada: ' + path)),
      );
    }
  }
}
