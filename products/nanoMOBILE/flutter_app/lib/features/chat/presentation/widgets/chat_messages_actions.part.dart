part of 'chat_messages.dart';

class MessageActions extends StatelessWidget {
  const MessageActions({
    super.key,
    required this.text,
    required this.model,
    required this.timestamp,
    this.onDelete,
  });

  final String text;
  final String model;
  final DateTime timestamp;
  final VoidCallback? onDelete;

  void _showActionsSheet(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.paddingOf(sheetContext).bottom + 20;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xF20B131E)
                    : colors.surface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: (isDark ? const Color(0xFF10B981) : colors.accent)
                      .withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.copy_rounded,
                    iconColor: colors.onSurface.withValues(alpha: 0.72),
                    label: 'Copiar',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Texto copiado al portapapeles'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.share_rounded,
                    iconColor: colors.onSurface.withValues(alpha: 0.72),
                    label: 'Compartir',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      SharePlus.instance.share(
                        ShareParams(
                          text: text,
                          subject: 'Respuesta NanoAI — $model',
                        ),
                      );
                    },
                  ),
                  if (onDelete != null)
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      iconColor: colors.danger,
                      label: 'Eliminar',
                      textColor: colors.danger,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onDelete?.call();
                      },
                    ),
                  Divider(
                    color: colors.onSurface.withValues(alpha: 0.12),
                    height: 24,
                  ),
                  _ActionTile(
                    icon: Icons.picture_as_pdf_rounded,
                    iconColor: colors.accent,
                    label: 'Exportar como PDF',
                    subtitle: 'Informe técnico estructurado',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await PdfReportService.exportReport(
                        title: 'Informe de Análisis NanoAI',
                        content: text,
                        modelName: model,
                        timestamp: timestamp,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.description_rounded,
                    iconColor: colors.success,
                    label: 'Exportar como Markdown',
                    subtitle: 'Archivo .md estructurado',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await PdfReportService.exportMarkdown(
                        title: 'Informe de Análisis NanoAI',
                        content: text,
                        modelName: model,
                        timestamp: timestamp,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Semantics(
      label: 'Acciones',
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showActionsSheet(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
      ),
    );
  }
}
