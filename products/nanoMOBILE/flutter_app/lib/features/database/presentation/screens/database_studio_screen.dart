// database_studio_screen.dart
//
// QUÉ HACE:
// Pantalla principal del Estudio de Base de Datos y SQL con soporte responsivo y Material Expressive 3.
//
// CÓMO FUNCIONA:
// - Usa el Overlay del Navigator raíz, evitando entradas que conserven estado antiguo.
// - Utiliza `OrientationBuilder` para alternar entre vista vertical y horizontal.
// - Provee acciones en la AppBar para conectar hojas Shell, exportar datos y generar informes PDF.
//
// POR QUÉ:
// Aplica SOLID y Clean Architecture reemplazando un monolito de 705 líneas por una estructura modular (< 170 líneas).

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import '../widgets/database_studio_actions.dart';
import 'database_studio_landscape_view.dart';
import 'database_studio_portrait_view.dart';

class DatabaseStudioScreen extends ConsumerStatefulWidget {
  const DatabaseStudioScreen({super.key});

  @override
  ConsumerState<DatabaseStudioScreen> createState() =>
      _DatabaseStudioScreenState();
}

class _DatabaseStudioScreenState extends ConsumerState<DatabaseStudioScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref
        .read(databaseStudioControllerProvider)
        .currentQuery;
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

    // Sincroniza cambios externos (tabla/fuente) sin escribir al controlador en build.
    ref.listen<DatabaseStudioState>(databaseStudioControllerProvider, (
      _,
      next,
    ) {
      if (_queryController.text == next.currentQuery) return;
      _queryController.value = TextEditingValue(
        text: next.currentQuery,
        selection: TextSelection.collapsed(offset: next.currentQuery.length),
      );
    });

    // GoRouter ya aporta el Overlay; Scaffold conserva la reactividad de Riverpod.
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.95),
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.table_chart_rounded,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            // Flexible evita el desbordamiento de píxeles en pantallas móviles
            Flexible(
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
                    'Emmanuel Higuita Gómez · Portafolio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          DatabaseStudioActions(controller: controller, colors: colors),
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
    );
  }
}
