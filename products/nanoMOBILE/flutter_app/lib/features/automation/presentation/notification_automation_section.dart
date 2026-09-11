import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/interactive_glass_card.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_section.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show
        conversationOwnershipStoreProvider,
        pendingRepliesProvider,
        pendingReplyStoreProvider;
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart'
    show conversationIdentityFor;
import 'package:nanoai/features/automation/engine/messaging/pending_reply.dart';
import 'package:nanoai/features/automation/executors/notification_executor.dart';
import 'package:nanoai/features/automation/executors/notification_executor_provider.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_owner.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'widgets/automation_suggestion_carousel.dart';
import 'widgets/conversation_detail_sheet.dart';
import 'widgets/conversation_list_tile.dart';

class NotificationAutomationSection extends ConsumerStatefulWidget {
  const NotificationAutomationSection({super.key});

  @override
  ConsumerState<NotificationAutomationSection> createState() =>
      _NotificationAutomationSectionState();
}

class _NotificationAutomationSectionState
    extends ConsumerState<NotificationAutomationSection>
    with WidgetsBindingObserver {
  final _draftController = TextEditingController();
  final _draftFocusNode = FocusNode();
  final _editorKey = GlobalKey();
  NotificationAccessStatus _status = const NotificationAccessStatus(
    accessGranted: false,
    connected: false,
  );
  List<DeviceNotification> _notifications = const [];
  DeviceNotification? _selected;
  bool _busy = false;
  String? _message;
  List<String> _suggestions = const [];

  NotificationExecutor get _service => ref.read(notificationExecutorProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftFocusNode.dispose();
    _draftController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final status = await _service.status();
    final notifications = status.connected
        ? await _service.list(limit: 30)
        : const <DeviceNotification>[];
    if (!mounted) return;
    final previousSelection = _selected;
    DeviceNotification? refreshedSelection;
    if (previousSelection != null) {
      for (final notification in notifications) {
        if (notification.key == previousSelection.key &&
            notification.canReply) {
          refreshedSelection = notification;
          break;
        }
      }
    }
    final selectionExpired =
        previousSelection != null && refreshedSelection == null;
    setState(() {
      _status = status;
      _notifications = notifications;
      _selected = refreshedSelection;
      _busy = false;
      if (selectionExpired) {
        _draftController.clear();
        _message =
            'La notificación seleccionada ya no está activa. Actualiza o elige otra.';
      }
    });
  }

  Future<void> _requestAccess() async {
    await _service.requestAccess();
  }

  void _select(DeviceNotification notification) {
    if (_busy || !notification.canReply) return;
    final changed = _selected?.key != notification.key;
    setState(() {
      _selected = notification;
      if (changed) {
        _draftController.clear();
        _suggestions = const [];
      }
      _message = 'Escribe una respuesta o genera un borrador local.';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selected?.key != notification.key) return;
      final editorContext = _editorKey.currentContext;
      if (editorContext != null) {
        Scrollable.ensureVisible(
          editorContext,
          duration: NanoMotionDurations.standard,
          curve: NanoCurves.easeOut,
          alignment: 0.25,
        );
      }
      _draftFocusNode.requestFocus();
    });
  }

  Future<void> _suggest(DeviceNotification notification) async {
    setState(() {
      _busy = true;
      _selected = notification;
      _message = 'Generando sugerencias…';
    });
    try {
      final suggestions = await _service.generateSuggestions(notification);
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _message = suggestions.isEmpty
            ? 'El motor local no produjo sugerencias. Genera un borrador o escribe manualmente.'
            : 'Elige una sugerencia para editarla; nada se envía sin revisar.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'No se pudieron generar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate(DeviceNotification notification) async {
    setState(() {
      _busy = true;
      _selected = notification;
      _message = 'Generando borrador local…';
    });
    try {
      final draft = await _service.generateLocalDraft(notification);
      if (!mounted) return;
      setState(() {
        _draftController.text = draft;
        _message = 'Revisa el texto antes de enviarlo.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'No se pudo generar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReply() async {
    final selected = _selected;
    final text = _draftController.text.trim();
    if (selected == null || text.isEmpty) return;
    final confirmed = await showNanoModalDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar respuesta'),
        content: Text('Se enviará a ${selected.title}:\n\n$text'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _message = 'Enviando mediante Android…';
    });
    bool sent;
    try {
      await ref.read(conversationOwnershipStoreProvider).load();
      await ref
          .read(conversationOwnershipStoreProvider)
          .setOwner(_conversationIdOf(selected), ConversationOwner.human);
      if (!mounted) return;
      final replyResult = await _service.confirmAndReply(selected, text);
      sent = replyResult.isAccepted;
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'No se pudo confirmar la respuesta: $error';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = sent
          ? 'Android entregó la respuesta a la aplicación.'
          : 'La acción expiró o la aplicación rechazó la respuesta.';
      if (sent) {
        _selected = null;
        _draftController.clear();
      }
    });
    if (sent) await _refresh();
  }

  /// PERSONA-TOOLS-10 — misma identidad que el pipeline: con la MISMA
  /// evidencia de Android (locusId/shortcutId/senderKey) la clave coincide y
  /// el ownership marcado aquí aplica a la conversación del listener.
  String _conversationIdOf(DeviceNotification notification) =>
      conversationIdentityFor(
        packageName: notification.packageName,
        accountHint: notification.accountHint,
        locusId: notification.locusId,
        shortcutId: notification.shortcutId,
        senderKey: notification.senderKey,
        conversationId: notification.conversationId,
        conversationTitle: notification.conversationTitle,
        title: notification.title,
        sender: notification.sender,
        isGroup: notification.isGroup,
        notificationKey: notification.key,
      ).key.id;

  /// PERSONA-TOOLS-10 — ¿la conversación seleccionada es del humano?
  /// Leído EN VIVO en cada build: el toggle refleja el store durable.
  bool get _selectedOwnership {
    final selected = _selected;
    if (selected == null) return false;
    final ownership = ref
        .read(conversationOwnershipStoreProvider)
        .ownershipFor(_conversationIdOf(selected));
    return ownership?.humanOwns ?? false;
  }

  Future<void> _setOwnership(bool humanOwns) async {
    final selected = _selected;
    if (selected == null || _busy) return;
    final store = ref.read(conversationOwnershipStoreProvider);
    setState(() => _busy = true);
    try {
      await store.load();
      await store.setOwner(
        _conversationIdOf(selected),
        humanOwns ? ConversationOwner.human : ConversationOwner.bot,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'No se pudo guardar el control: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final replyable = _notifications
        .where((notification) => notification.canReply)
        .toList(growable: false);
    final readOnly = _notifications
        .where((notification) => !notification.canReply)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ConversationsHubSection(),
        _PendingRepliesSection(
          activeNotifications: _notifications,
          onReplied: _refresh,
        ),
        SectionHeader(
          'Notificaciones locales',
          Icons.notifications_active_rounded,
          colors: colors,
        ),
        InteractiveGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(NanoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Borradores locales. Nada se envía sin confirmar.',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
                const SizedBox(height: NanoSpacing.md),
                if (!_status.accessGranted)
                  FilledButton.icon(
                    onPressed: _busy ? null : _requestAccess,
                    icon: const Icon(Icons.security_rounded),
                    label: const Text('Conceder acceso en Android'),
                  )
                else if (!_status.connected)
                  Text(
                    'Acceso concedido; esperando que Android conecte el servicio.',
                    style: NanoType.caption(colors.onSurfaceVariant),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_notifications.length} notificaciones activas',
                          style: NanoType.body(colors.onSurface),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _busy ? null : _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (_notifications.isEmpty)
                    Text(
                      'No hay notificaciones disponibles.',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                  if (_notifications.isNotEmpty && replyable.isEmpty) ...[
                    const SizedBox(height: NanoSpacing.sm),
                    _CapabilityNotice(
                      icon: Icons.mark_chat_unread_outlined,
                      text:
                          'Android no expone respuesta directa en las notificaciones actuales.',
                      color: colors.warning,
                    ),
                  ],
                  if (replyable.isNotEmpty) ...[
                    const SizedBox(height: NanoSpacing.sm),
                    _ListLabel(
                      label: 'Disponibles para responder',
                      count: replyable.length,
                    ),
                    const SizedBox(height: NanoSpacing.xs),
                    for (final notification in replyable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: NanoSpacing.xs),
                        child: _NotificationTile(
                          notification: notification,
                          selected: _selected?.key == notification.key,
                          enabled: !_busy,
                          onTap: () => _select(notification),
                        ),
                      ),
                  ],
                  if (readOnly.isNotEmpty) ...[
                    const SizedBox(height: NanoSpacing.sm),
                    _ReadOnlyNotifications(notifications: readOnly),
                  ],
                ],
                if (_selected != null) ...[
                  const SizedBox(height: NanoSpacing.md),
                  AnimatedSwitcher(
                    key: _editorKey,
                    duration: NanoMotionDurations.standard,
                    switchInCurve: NanoCurves.easeOut,
                    child: Container(
                      key: ValueKey(_selected!.key),
                      padding: const EdgeInsets.all(NanoSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.34),
                        borderRadius: NanoShapes.medium,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.reply_rounded,
                                size: NanoIcons.small,
                                color: colors.primary,
                              ),
                              const SizedBox(width: NanoSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Responder a ${_notificationTitle(_selected!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NanoType.label(colors.onSurface),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar editor',
                                onPressed: _busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selected = null;
                                          _draftController.clear();
                                          _suggestions = const [];
                                          _message = null;
                                        });
                                      },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: NanoSpacing.sm),
                          _OwnershipControl(
                            humanOwns: _selectedOwnership,
                            busy: _busy,
                            onTakeOver: () => _setOwnership(true),
                            onHandBack: () => _setOwnership(false),
                          ),
                          const SizedBox(height: NanoSpacing.sm),
                          TextField(
                            focusNode: _draftFocusNode,
                            controller: _draftController,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 2000,
                            enabled: !_busy,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Escribe tu respuesta…',
                              labelText: 'Respuesta editable',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_suggestions.isNotEmpty) ...[
                            const SizedBox(height: NanoSpacing.sm),
                            AutomationSuggestionCarousel(
                              key: ValueKey(_suggestions),
                              suggestions: [
                                for (final suggestion in _suggestions)
                                  AutomationSuggestion(
                                    leading: const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: NanoIcons.small,
                                    ),
                                    label: suggestion,
                                    onSelected: _busy
                                        ? null
                                        : () {
                                            setState(() {
                                              _draftController.text =
                                                  suggestion;
                                              _message =
                                                  'Sugerencia cargada. Revísala antes de enviar.';
                                            });
                                          },
                                  ),
                              ],
                            ),
                          ],
                          Wrap(
                            spacing: NanoSpacing.sm,
                            runSpacing: NanoSpacing.sm,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _suggest(_selected!),
                                icon: const Icon(
                                  Icons.lightbulb_outline_rounded,
                                ),
                                label: const Text('Sugerir'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _generate(_selected!),
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: const Text('Generar borrador'),
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _draftController,
                                builder: (context, value, _) =>
                                    FilledButton.icon(
                                      onPressed:
                                          _busy || value.text.trim().isEmpty
                                          ? null
                                          : _confirmReply,
                                      icon: const Icon(Icons.send_rounded),
                                      label: const Text('Revisar y enviar'),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: NanoSpacing.sm),
                  const LinearProgressIndicator(),
                ],
                if (_message != null) ...[
                  const SizedBox(height: NanoSpacing.sm),
                  Text(
                    _message!,
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _notificationTitle(DeviceNotification notification) =>
    notification.title.trim().isEmpty
    ? notification.packageName
    : notification.title.trim();

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
        final replyResult = await service.confirmAndReply(match, reply.draftText);
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
                    style: NanoType.caption(colors.primary).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    reply.sender,
                    style: NanoType.label(colors.onSurface),
                  ),
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
                style: NanoType.body(colors.onSurface).copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: NanoSpacing.xs),
              Row(
                children: [
                  Icon(
                    expired
                        ? Icons.timer_off_outlined
                        : Icons.timer_outlined,
                    size: 13,
                    color: expiryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expiryLabel,
                    style: NanoType.caption(expiryColor),
                  ),
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

class _ConversationsHubSection extends ConsumerWidget {
  const _ConversationsHubSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final asyncList = ref.watch(conversationHubListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Centro de Conversaciones',
          Icons.forum_rounded,
          colors: colors,
        ),
        asyncList.when(
          data: (items) {
            if (items.isEmpty) {
              return InteractiveGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(NanoSpacing.md),
                  child: Text(
                    'No hay conversaciones registradas. Las conversaciones activas de WhatsApp u otras apps aparecerán aquí al recibir mensajes.',
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final item in items)
                  ConversationListTile(
                    item: item,
                    onTap: () => ConversationDetailSheet.show(context, item),
                    onApprovePending: item.hasPendingReply
                        ? () => ConversationDetailSheet.show(context, item)
                        : null,
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Text(
            'Error al cargar conversaciones: $err',
            style: TextStyle(color: colors.error),
          ),
        ),
        const SizedBox(height: NanoSpacing.lg),
      ],
    );
  }
}

