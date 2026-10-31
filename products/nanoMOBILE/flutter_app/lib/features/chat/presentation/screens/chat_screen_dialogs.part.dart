part of 'chat_screen.dart';

// chat_screen_dialogs.part.dart — Diálogos de confirmación Liquid Glass del chat.
// QUÉ HACE: Despliega ventanas flotantes de confirmación para limpiar chat, eliminar mensajes o autorizar tools.
// CÓMO FUNCIONA: Usa showNanoGlassWindow con cristal iOS, tipografía Inter y CupertinoIcons profesionales.
// POR QUÉ: Sustituye modales Material crudos por ventanas Liquid Glass unificadas (< 180 líneas).

extension _ChatScreenDialogs on _ChatScreenState {
  /// QUÉ HACE: Diálogo Liquid Glass para vaciar por completo el historial de la conversación.
  /// CÓMO FUNCIONA: Solicita validación explícita del usuario antes de invocar notifier.clear().
  Future<void> _showClearDialog(ChatNotifier notifier) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showNanoGlassWindow<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.trash_fill,
                      color: colors.danger,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¿Limpiar conversación?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Se eliminarán los mensajes activos de la pantalla. Esta acción no se puede deshacer.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Limpiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await notifier.clear();
    }
  }

  /// QUÉ HACE: Diálogo para eliminar un mensaje individual específico.
  Future<void> _showDeleteDialog(
    ChatNotifier notifier,
    ChatMessage message,
  ) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showNanoGlassWindow<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.trash_fill,
                      color: colors.danger,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¿Eliminar mensaje?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.text.length > 80
                  ? '"${message.text.substring(0, 80)}…"'
                  : '"${message.text}"',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      notifier.delete(message.id);
    }
  }

  /// QUÉ HACE: Barrera de confirmación Liquid Glass para tool-calling (Política §12).
  Future<void> _showToolConfirmDialog(String tool) async {
    final description = ref.read(chatProvider).pendingToolDescription ?? '';
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final approved = await showNanoGlassWindow<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      color: colors.primary,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirmar acción "$tool"',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description.isEmpty
                  ? 'El agente solicita permiso para ejecutar "$tool" en el dispositivo.'
                  : description,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Permitir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (approved == null || !mounted) return;
    final notifier = ref.read(chatProvider.notifier);
    if (approved) {
      await notifier.approvePendingTool();
    } else {
      await notifier.rejectPendingTool();
    }
  }
}