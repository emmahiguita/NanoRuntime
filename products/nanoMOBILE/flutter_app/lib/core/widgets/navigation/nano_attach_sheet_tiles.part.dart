part of 'nano_attach_sheet.dart';

// nano_attach_sheet_tiles.part.dart — Fila superior de selección de archivos multimedia.
// QUÉ HACE: Renderiza los botones de acción rápida para adjuntar fotos, documentos, audios o videos.
// CÓMO FUNCIONA: Discos circulares translúcidos Liquid Glass con glifos limpios monocromos sin saturación.
// POR QUÉ: Depura las cajas de colores pastel saturados por estética iOS auténtica (< 120 líneas).

/// Fila superior de 4 tipos de adjuntos multimedia estilo iOS Liquid Glass.
class _FileAttachSection extends StatelessWidget {
  const _FileAttachSection();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _FileTile(
          icon: CupertinoIcons.camera,
          title: 'Cámara',
          onTap: () => Navigator.of(context).pop(NanoAttachKind.photo),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _FileTile(
          icon: CupertinoIcons.doc,
          title: 'Documento',
          onTap: () => Navigator.of(context).pop(NanoAttachKind.document),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _FileTile(
          icon: CupertinoIcons.mic,
          title: 'Audio',
          onTap: () => Navigator.of(context).pop(NanoAttachKind.audio),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _FileTile(
          icon: CupertinoIcons.videocam,
          title: 'Video',
          onTap: () => Navigator.of(context).pop(NanoAttachKind.video),
        ),
      ),
    ],
  );
}

/// Etiqueta de sección estilo iOS con tipografía nítida en mayúsculas sutiles.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4, bottom: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.50)),
            const SizedBox(width: 5),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.onSurfaceVariant.withValues(alpha: 0.55),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular de tipo de archivo estilo iOS Action Sheet con retroalimentación háptica.
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.20),
                    width: 0.7,
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: colors.onSurface, size: 21),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
