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
    showNanoGlassWindow(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              color: colors.onSurfaceVariant.withValues(alpha: 0.70),
            ),
          ),
        ),
      ),
    );
  }
}
