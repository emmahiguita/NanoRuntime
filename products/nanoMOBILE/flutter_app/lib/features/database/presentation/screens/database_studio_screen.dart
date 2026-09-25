// database_studio_screen.dart
//
// QUÉ HACE:
// Pantalla principal del Estudio de Base de Datos y SQL con soporte responsivo y Material Expressive 3.
//
// CÓMO FUNCIONA:
// - Envuelve el árbol en un widget `Overlay` explícito para corregir el error visual "No Overlay".
// - Utiliza `OrientationBuilder` para alternar entre vista vertical y horizontal (2 paneles balanceados).
// - Provee acciones en la AppBar para conectar hojas Shell, exportar datos y generar informes PDF.
//
// POR QUÉ:
// Aplica SOLID y Clean Architecture reemplazando un monolito de 705 líneas por una estructura modular (< 170 líneas).

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import '../widgets/database_pdf_dialog.dart';
import '../widgets/database_shell_connect_dialog.dart';
import 'database_studio_landscape_view.dart';
import 'database_studio_portrait_view.dart';

class DatabaseStudioScreen extends ConsumerStatefulWidget {
  const DatabaseStudioScreen({super.key});

  @override
  ConsumerState<DatabaseStudioScreen> createState() => _DatabaseStudioScreenState();
}

class _DatabaseStudioScreenState extends ConsumerState<DatabaseStudioScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(databaseStudioControllerProvider).currentQuery;
    _queryController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final state = ref.watch(databaseStudioControllerProvider);
    final controller = ref.read(databaseStudioControllerProvider.notifier);

    if (_queryController.text != state.currentQuery && !FocusScope.of(context).hasFocus) {
      _queryController.text = state.currentQuery;
    }

    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (overlayContext) => Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface.withValues(alpha: 0.95),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.table_chart_rounded, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Data Studio & SQL',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          'Base de datos real, SQLite y Hojas Shell',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Conectar Hoja Shell',
                  icon: Icon(Icons.add_link_rounded, color: colors.primary, size: 22),
                  onPressed: () => _openConnectShellDialog(overlayContext, controller, colors),
                ),
                IconButton(
                  tooltip: 'Exportar a Shell',
                  icon: Icon(Icons.terminal_rounded, color: colors.accent, size: 22),
                  onPressed: () => _exportToShell(overlayContext, controller),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                    label: const Text('PDF', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _openPdfDialog(overlayContext, controller, colors),
                  ),
                ),
              ],
            ),
            body: OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return DatabaseStudioLandscapeView(
                    state: state,
                    controller: controller,
                    queryController: _queryController,
                    colors: colors,
                  );
                }
                return DatabaseStudioPortraitView(
                  state: state,
                  controller: controller,
                  queryController: _queryController,
                  colors: colors,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openConnectShellDialog(BuildContext context, DatabaseStudioController controller, NanoColors colors) {
    DatabaseShellConnectDialog.show(context, controller: controller, colors: colors);
  }

  void _openPdfDialog(BuildContext context, DatabaseStudioController controller, NanoColors colors) {
    DatabasePdfDialog.show(context, controller: controller, colors: colors);
  }

  void _exportToShell(BuildContext context, DatabaseStudioController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await controller.exportToShellDirectory();
    if (!mounted || path == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Guardado en entorno Shell: $path', style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: Colors.teal,
        action: SnackBarAction(label: 'Copiar Ruta', textColor: Colors.white, onPressed: () => Clipboard.setData(ClipboardData(text: path))),
      ),
    );
  }
}
