part of 'notification_automation_section.dart';

/// PERSONA-TOOLS-10 — control de ownership de la conversación seleccionada.
/// El estado viene del store durable (bot por defecto = paridad con el
/// comportamiento anterior); el humano toma el control con un toque y lo
/// devuelve con otro. Honesto: el agente nunca responde mientras el humano
/// la atiende (DecisionEngine holdForApproval).
class _OwnershipControl extends StatelessWidget {
  const _OwnershipControl({
    required this.humanOwns,
    required this.busy,
    required this.onTakeOver,
    required this.onHandBack,
  });

  final bool humanOwns;
  final bool busy;
  final VoidCallback onTakeOver;
  final VoidCallback onHandBack;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NanoSpacing.sm,
        vertical: NanoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: (humanOwns ? colors.warning : colors.primary).withValues(
          alpha: 0.08,
        ),
        borderRadius: NanoShapes.small,
        border: Border.all(
          color: (humanOwns ? colors.warning : colors.primary).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            humanOwns ? Icons.person_rounded : Icons.smart_toy_outlined,
            size: NanoIcons.small,
            color: humanOwns ? colors.warning : colors.primary,
          ),
          const SizedBox(width: NanoSpacing.sm),
          Expanded(
            child: Text(
              humanOwns
                  ? 'La atiendes tú: Nano no responderá a esta conversación.'
                  : 'Nano responde solo a esta conversación.',
              style: NanoType.caption(colors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: busy
                ? null
                : humanOwns
                ? onHandBack
                : onTakeOver,
            child: Text(humanOwns ? 'Devuélvelo a Nano' : 'La atiendo yo'),
          ),
        ],
      ),
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Row(
      children: [
        Expanded(child: Text(label, style: NanoType.label(colors.onSurface))),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NanoSpacing.sm,
            vertical: NanoSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: NanoShapes.full,
          ),
          // UI-REV-06: acento crudo sobre su propio fondo no pasa AA —
          // variante legible de la misma familia.
          child: Text(
            '$count',
            style: NanoType.caption(
              NanoTextColors.forText(colors.primary, colors),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DeviceNotification notification;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    // UI-REV-06: entrada animada (fade + desliz sutil) y mensaje COMPLETO
    // en Inter — sin ellipsis que corten la frase. El contenido de la
    // notificación es lo que el usuario viene a leer.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NanoMotionDurations.standard,
      curve: NanoCurves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.small,
          side: BorderSide(
            color: selected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          enabled: enabled,
          selected: selected,
          onTap: enabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: NanoSpacing.md,
            vertical: NanoSpacing.xs,
          ),
          leading: CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            foregroundColor: colors.primary,
            child: const Icon(Icons.reply_rounded),
          ),
          title: Text(
            _notificationTitle(notification),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NanoType.body(colors.onSurface),
          ),
          subtitle: Text(
            notification.text.trim().isEmpty
                ? notification.packageName
                : notification.text.trim(),
            style: NanoType.caption(
              colors.onSurfaceVariant,
            ).copyWith(height: 1.35),
          ),
          trailing: AnimatedSwitcher(
            duration: NanoMotionDurations.quick,
            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              key: ValueKey(selected),
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyNotifications extends StatelessWidget {
  const _ReadOnlyNotifications({required this.notifications});

  final List<DeviceNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      leading: Icon(Icons.visibility_outlined, color: colors.onSurfaceVariant),
      title: Text(
        'Solo lectura (${notifications.length})',
        style: NanoType.label(colors.onSurfaceVariant),
      ),
      subtitle: Text(
        'Android no permite responderlas directamente.',
        style: NanoType.caption(colors.onSurfaceVariant),
      ),
      children: [
        for (final notification in notifications)
          ListTile(
            enabled: false,
            contentPadding: const EdgeInsets.only(left: NanoSpacing.md),
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(
              _notificationTitle(notification),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // UI-REV-06: contenido completo, sin cortar la frase.
            subtitle: Text(
              notification.text.trim().isEmpty
                  ? 'Sin contenido visible'
                  : notification.text.trim(),
            ),
          ),
      ],
    );
  }
}

class _CapabilityNotice extends StatelessWidget {
  const _CapabilityNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(NanoSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: NanoShapes.small,
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: NanoSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// WA-DRAFT-INBOX-01 — Sección reactiva de borradores pendientes de aprobación.
