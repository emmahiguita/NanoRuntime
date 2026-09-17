part of 'notification_automation_section.dart';

class _PendingRepliesSection extends ConsumerWidget {
  const _PendingRepliesSection({
    required this.activeNotifications,
    required this.onReplied,
  });

  final List<DeviceNotification> activeNotifications;
  final VoidCallback onReplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingRepliesProvider);
    final colors = NanoThemeExtension.of(context).colors;

    return pendingAsync.when(
      data: (replies) {
        if (replies.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Respuestas pendientes de aprobación',
              Icons.mark_chat_unread_rounded,
              colors: colors,
            ),
            for (final reply in replies)
              _PendingReplyCard(
                reply: reply,
                activeNotifications: activeNotifications,
                onReplied: onReplied,
              ),
            const SizedBox(height: NanoSpacing.md),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PendingReplyCard extends ConsumerStatefulWidget {
  const _PendingReplyCard({
    required this.reply,
    required this.activeNotifications,
    required this.onReplied,
  });

  final PendingReply reply;
  final List<DeviceNotification> activeNotifications;
  final VoidCallback onReplied;

  @override
  ConsumerState<_PendingReplyCard> createState() => _PendingReplyCardState();
}

class _PendingReplyCardState extends ConsumerState<_PendingReplyCard> {
  bool _isSending = false;

  PendingReply get reply => widget.reply;
  List<DeviceNotification> get activeNotifications =>
      widget.activeNotifications;
  VoidCallback get onReplied => widget.onReplied;

  Future<void> _send() async {
    if (_isSending || !reply.isActionable) return;
    setState(() => _isSending = true);

    try {
      final store = ref.read(pendingReplyStoreProvider);
      final service = ref.read(notificationExecutorProvider);

      await store.beginDispatch(reply.id);

      final match = activeNotifications.where((n) {
        if (!n.canReply) return false;
        final identity = conversationIdentityFor(
          packageName: n.packageName,
          accountHint: n.accountHint,
          locusId: n.locusId,
          shortcutId: n.shortcutId,
          senderKey: n.senderKey,
          conversationId: n.conversationId,
          conversationTitle: n.conversationTitle,
          title: n.title,
          sender: n.sender,
          isGroup: n.isGroup,
          notificationKey: n.key,
        );
        return reply.matchesSource(
          conversationId: identity.key.id,
          packageName: n.packageName,
          notificationKey: n.key,
          notificationPostTime: n.postedAt.millisecondsSinceEpoch,
        );
      }).firstOrNull;

      if (match != null) {
        final replyResult = await service.confirmAndReply(
          match,
          reply.draftText,
        );
        if (replyResult.isAccepted) {
          await store.markSent(reply.id);
          ref.invalidate(pendingRepliesProvider);
          onReplied();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Respuesta enviada a ${reply.sender}')),
            );
          }
          return;
        } else if (replyResult.isContextChanged) {
          await store.markContextChanged(reply.id);
          ref.invalidate(pendingRepliesProvider);
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Turno cambiado en WhatsApp'),
                content: Text(
                  'El estado de la conversación con ${reply.sender} cambió en Android mientras revisabas el borrador.\n\n'
                  'Por seguridad (evitar responder fuera de contexto o al contacto equivocado), el borrador no fue enviado.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      await store.markContextChanged(reply.id);
      ref.invalidate(pendingRepliesProvider);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Notificación no encontrada'),
            content: Text(
              'La notificación de ${reply.sender} ya no está activa en la barra de Android.\n\n'
              'El borrador ha sido marcado como contexto cambiado. Puedes copiar el texto para responder directamente en la aplicación.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar borrador'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: reply.draftText));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Borrador copiado al portapapeles'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _edit() async {
    if (_isSending) return;
    final controller = TextEditingController(text: reply.draftText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar borrador para ${reply.sender}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Escribe la respuesta...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newText != null && newText.isNotEmpty) {
      await ref
          .read(pendingReplyStoreProvider)
          .updateDraftText(reply.id, newText);
      ref.invalidate(pendingRepliesProvider);
    }
  }

  Future<void> _dismiss() async {
    if (_isSending) return;
    await ref.read(pendingReplyStoreProvider).dismiss(reply.id);
    ref.invalidate(pendingRepliesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isBusiness = reply.packageName.contains('w4b');
    final appLabel = isBusiness ? 'WhatsApp Business' : 'WhatsApp';

    final expired = reply.isExpired;
    final actionable = reply.isActionable;
    final timeLeft = reply.expiresAt.difference(DateTime.now());
    final expiryLabel = expired
        ? 'Contexto expirado'
        : timeLeft.inHours > 0
        ? 'Expira en ${timeLeft.inHours}h'
        : 'Expira en ${timeLeft.inMinutes}m';
    final expiryColor = expired
        ? colors.error
        : (timeLeft.inMinutes < 60 ? colors.warning : colors.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(bottom: NanoSpacing.sm),
      child: InteractiveGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(NanoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBusiness
                        ? Icons.business_center_outlined
                        : Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    appLabel,
                    style: NanoType.caption(
                      colors.primary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(reply.sender, style: NanoType.label(colors.onSurface)),
                ],
              ),
              const SizedBox(height: NanoSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(NanoSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mensaje original:',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                    Text(
                      reply.originalMessage,
                      style: NanoType.body(colors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NanoSpacing.sm),
              Text(
                'Borrador propuesto:',
                style: NanoType.caption(colors.primary),
              ),
              const SizedBox(height: 2),
              Text(
                reply.draftText,
                style: NanoType.body(
                  colors.onSurface,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              if (reply.suggestions.length > 1) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (int i = 0; i < reply.suggestions.length; i++)
                      () {
                        final opt = reply.suggestions[i];
                        final isSelected = reply.draftText.trim() == opt.trim();
                        return ActionChip(
                          avatar: Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 12,
                            color: isSelected ? Colors.white : colors.primary,
                          ),
                          label: Text(
                            'Opción ${i + 1}: ${opt.length > 22 ? "${opt.substring(0, 22)}..." : opt}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : colors.onSurface,
                            ),
                          ),
                          backgroundColor: isSelected
                              ? colors.primary
                              : colors.surfaceVariant.withValues(alpha: 0.35),
                          side: BorderSide(
                            color: isSelected
                                ? colors.primary
                                : colors.surfaceVariant.withValues(alpha: 0.6),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          onPressed: _isSending
                              ? null
                              : () async {
                                  if (!isSelected) {
                                    await ref
                                        .read(pendingReplyStoreProvider)
                                        .updateDraftText(reply.id, opt);
                                    ref.invalidate(pendingRepliesProvider);
                                  }
                                },
                        );
                      }(),
                  ],
                ),
              ],
              const SizedBox(height: NanoSpacing.xs),
              Row(
                children: [
                  Icon(
                    expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                    size: 13,
                    color: expiryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(expiryLabel, style: NanoType.caption(expiryColor)),
                ],
              ),
              const SizedBox(height: NanoSpacing.sm),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: NanoSpacing.xs,
                runSpacing: NanoSpacing.xs,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Descartar'),
                    onPressed: _isSending ? null : _dismiss,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                    onPressed: _isSending ? null : _edit,
                  ),
                  FilledButton.icon(
                    icon: _isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            expired
                                ? Icons.timer_off_rounded
                                : Icons.send_rounded,
                            size: 16,
                          ),
                    label: Text(
                      _isSending
                          ? 'Enviando...'
                          : (expired ? 'Expirado' : 'Enviar'),
                    ),
                    onPressed: (actionable && !_isSending) ? _send : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

