import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/interactive_glass_card.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_section.dart';
import 'package:nanoai/features/automation/executors/notification_executor.dart';
import 'package:nanoai/features/automation/executors/notification_executor_provider.dart';

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
      if (changed) _draftController.clear();
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
    final sent = await _service.confirmAndReply(selected, text);
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
                  'NanoRuntime redacta localmente. Nada se envía sin tu confirmación.',
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
                                          _message = null;
                                        });
                                      },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
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
                          Wrap(
                            spacing: NanoSpacing.sm,
                            runSpacing: NanoSpacing.sm,
                            alignment: WrapAlignment.end,
                            children: [
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
          child: Text('$count', style: NanoType.caption(colors.primary)),
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
    return Material(
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NanoType.body(colors.onSurface),
        ),
        subtitle: Text(
          notification.text.trim().isEmpty
              ? notification.packageName
              : notification.text.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: NanoType.caption(colors.onSurfaceVariant),
        ),
        trailing: AnimatedSwitcher(
          duration: NanoMotionDurations.quick,
          child: Icon(
            selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            key: ValueKey(selected),
            color: selected ? colors.primary : colors.onSurfaceVariant,
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
            subtitle: Text(
              notification.text.trim().isEmpty
                  ? 'Sin contenido visible'
                  : notification.text.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
