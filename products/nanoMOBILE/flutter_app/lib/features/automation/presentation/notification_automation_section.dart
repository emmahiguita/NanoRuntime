import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_section.dart';
import 'package:nanoai/features/automation/executors/notification_executor.dart';

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
  NotificationAccessStatus _status = const NotificationAccessStatus(
    accessGranted: false,
    connected: false,
  );
  List<DeviceNotification> _notifications = const [];
  DeviceNotification? _selected;
  bool _busy = false;
  String? _message;

  NotificationExecutor get _service => NotificationExecutor(
    runtime: NanoRuntimeApi.instance,
    engine: ref.read(runtimeEngineProvider.notifier).client,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    setState(() {
      _status = status;
      _notifications = notifications;
      _busy = false;
    });
  }

  Future<void> _requestAccess() async {
    await _service.requestAccess();
  }

  Future<void> _generate(DeviceNotification notification) async {
    setState(() {
      _busy = true;
      _selected = notification;
      _draftController.clear();
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
    final confirmed = await showDialog<bool>(
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
          ? 'Respuesta enviada.'
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Notificaciones locales',
          Icons.notifications_active_rounded,
          colors: colors,
        ),
        SettingsCard(
          shadow: NanoShadows.card(colors),
          colors: colors,
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _requestAccess,
                      icon: const Icon(Icons.security_rounded),
                      label: const Text('Conceder acceso en Android'),
                    ),
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
                  for (final notification in _notifications)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        notification.canReply
                            ? Icons.reply_rounded
                            : Icons.notifications_none_rounded,
                        color: notification.canReply
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(
                        notification.title.isEmpty
                            ? notification.packageName
                            : notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        notification.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: notification.canReply
                          ? TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _generate(notification),
                              child: const Text('Borrador'),
                            )
                          : null,
                    ),
                ],
                if (_selected != null) ...[
                  const Divider(),
                  TextField(
                    controller: _draftController,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 2000,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Respuesta editable',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _confirmReply,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Revisar y enviar'),
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
