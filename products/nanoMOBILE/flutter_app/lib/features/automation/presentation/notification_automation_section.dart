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
import 'widgets/automation_suggestion_carousel.dart';

part 'notification_automation_widgets.dart';
part 'notification_automation_pending.dart';

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
