part of 'chat_screen.dart';

// chat_screen_attachments_view.part.dart — Tira de pastillas flotantes de archivos adjuntos.
// QUÉ HACE: Muestra los archivos seleccionados sobre cápsulas Liquid Glass limpias e independientes.
// CÓMO FUNCIONA: Permite desplazarse horizontalmente, muestra el tipo con CupertinoIcons y botón de descarte.
// POR QUÉ: Elimina cajas opacas toscas y bordes artificiales, integrándose con el compositor (< 100 líneas).

class _AttachmentPillsStrip extends StatelessWidget {
  const _AttachmentPillsStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<ChatAttachment> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: attachments.map((att) {
          final IconData kindIcon = switch (att.kind) {
            ChatAttachmentKind.photo => CupertinoIcons.photo_fill,
            ChatAttachmentKind.video => CupertinoIcons.videocam_fill,
            ChatAttachmentKind.audio => CupertinoIcons.mic_fill,
            ChatAttachmentKind.document ||
            ChatAttachmentKind.text => CupertinoIcons.doc_fill,
          };

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.fromLTRB(9, 4.5, 6, 4.5),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: isDark ? 0.70 : 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.outlineVariant.withValues(
                  alpha: isDark ? 0.35 : 0.25,
                ),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  kindIcon,
                  size: 13,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    att.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onRemove(att.name);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 14,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}