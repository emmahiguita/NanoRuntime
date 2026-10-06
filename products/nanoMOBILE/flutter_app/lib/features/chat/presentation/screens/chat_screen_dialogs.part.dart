part of 'chat_screen.dart';

// QUÉ HACE:
// Gestiona los diálogos modales de confirmación e interacción crítica del chat.
//
// CÓMO FUNCIONA:
// - Despliega modales de advertencia al limpiar el historial o eliminar mensajes.
// - Implementa la barrera de confirmación obligatoria para tool-calling (Política §12)
//   mediante showNanoModalDialog con Material y Overlay local garantizado.
//
// POR QUÉ:
// Aplica principios SOLID (Single Responsibility Principle) encapsulando la lógica
// modal en un archivo compacto (< 140 líneas) sin procesos zombies ni fugas de memoria.
extension _ChatScreenDialogs on _ChatScreenState {
  /// QUÉ HACE: Diálogo de confirmación para vaciar por completo el historial de la conversación.
  /// CÓMO FUNCIONA: Solicita validación explícita del usuario antes de invocar `notifier.clear()`.
  /// POR QUÉ: Evita pérdidas accidentales de datos en el chat activo.
  Future<void> _showClearDialog(ChatNotifier notifier) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showNanoModalDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
        ),
        title: Text(
          '¿Limpiar conversación?',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          'Se eliminarán todos los mensajes. Esta acción no se puede deshacer.',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await notifier.clear();
    }
  }

  /// QUÉ HACE: Diálogo para eliminar un mensaje individual específico.
  /// CÓMO FUNCIONA: Muestra una vista previa del texto y confirma su eliminación selectiva.
  /// POR QUÉ: Permite al usuario depurar turnos o errores puntuales sin perder toda la sesión.
  Future<void> _showDeleteDialog(
    ChatNotifier notifier,
    ChatMessage message,
  ) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showNanoModalDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
        ),
        title: Text(
          '¿Eliminar mensaje?',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          message.text.length > 80
              ? '"${message.text.substring(0, 80)}…"'
              : '"${message.text}"',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      notifier.delete(message.id);
    }
  }

  /// QUÉ HACE: Barrera de confirmación para tool-calling (Política §12).
  /// CÓMO FUNCIONA: Si el agente desea ejecutar una acción en el dispositivo,
  ///   requiere aprobación explícita del humano; si se rechaza, cancela la acción.
  /// POR QUÉ: Garantiza control y seguridad absoluta sobre ejecuciones locales en Android/Linux.
  Future<void> _showToolConfirmDialog(String tool) async {
    final description = ref.read(chatProvider).pendingToolDescription ?? '';
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final approved = await showNanoModalDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Confirmar acción "$tool"',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          description.isEmpty
              ? 'El agente quiere ejecutar "$tool" en el dispositivo.'
              : description,
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Permitir'),
          ),
        ],
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
