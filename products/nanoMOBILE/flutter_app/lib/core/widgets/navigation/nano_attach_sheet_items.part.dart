part of 'nano_attach_sheet.dart';

// nano_attach_sheet_items.part.dart — Comandos de hardware y sistema en lista iOS directa.
// QUÉ HACE: Renderiza comandos rápidos del dispositivo con iconografía limpia sin tarjetas encerradas.
// CÓMO FUNCIONA: Despliega filas táctiles directamente sobre el cristal Liquid Glass con divisores tenues.
// POR QUÉ: Depura las cajas internas y colores saturados para un diseño iOS limpio (< 120 líneas).

/// Sección de comandos y herramientas estilo lista directa iOS Liquid Glass.
class _CommandInjectSection extends StatelessWidget {
  const _CommandInjectSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _CommandTile(
          title: 'Diagnóstico del dispositivo',
          subtitle: 'CPU, memoria y sensores',
          command: '@mcp call device.diagnostics',
          icon: CupertinoIcons.gauge,
          showDivider: true,
        ),
        _CommandTile(
          title: 'Búsqueda web en vivo',
          subtitle: 'Consultar información en internet',
          command: '@buscar ',
          icon: CupertinoIcons.search,
          showDivider: true,
        ),
        _CommandTile(
          title: 'Estado del proyecto Git',
          subtitle: 'Ver cambios y estado del árbol',
          command: '@git status',
          icon: CupertinoIcons.arrow_branch,
          showDivider: true,
        ),
        _CommandTile(
          title: 'Resumen de aplicaciones',
          subtitle: 'Apps y servicios instalados',
          command: '@mcp call device.app_summary',
          icon: CupertinoIcons.square_grid_2x2,
          showDivider: false,
        ),
      ],
    );
  }
}

/// Fila interactiva estilo iOS List Tile directa para ejecutar comandos y herramientas.
class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.title,
    required this.subtitle,
    required this.command,
    required this.icon,
    required this.showDivider,
  });

  final String title;
  final String subtitle;
  final String command;
  final IconData icon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop(command);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8.5),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Icon(icon, color: colors.onSurfaceVariant, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.15,
                          ),
                        ),
                        const SizedBox(height: 1.5),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.onSurfaceVariant.withValues(alpha: 0.70),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 4),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: colors.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
      ],
    );
  }
}
