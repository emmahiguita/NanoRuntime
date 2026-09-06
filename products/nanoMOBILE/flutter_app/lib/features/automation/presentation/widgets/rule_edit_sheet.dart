import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import '../../engine/scheduling/scheduled_rule.dart';
import '../../engine/scheduling/trigger.dart';
import '../automation_visual_theme.dart';

/// RULES-EDIT-01 — edición profesional de una regla existente.
///
/// Editor estructurado (no reparseo frágil de texto): según el tipo de
/// trigger muestra hora+días o contacto+contenido, y siempre acción, texto,
/// respuesta dinámica y archivo. Devuelve la [ScheduledRule] actualizada por
/// `Navigator.pop`; el caller aplica `RuleRegistry.update` (el sheet no toca
/// el registro: presentación pura).
class RuleEditSheet extends StatefulWidget {
  const RuleEditSheet({super.key, required this.rule});

  final ScheduledRule rule;

  @override
  State<RuleEditSheet> createState() => _RuleEditSheetState();
}

class _RuleEditSheetState extends State<RuleEditSheet> {
  late RuleAction _action;
  late final TextEditingController _message;
  late final TextEditingController _contact;
  late final TextEditingController _textMatch;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late bool _dynamicReply;
  String? _newMediaPath;
  String? _error;

  ScheduledRule get rule => widget.rule;
  bool get _isTime => rule.trigger is TimeTrigger;
  bool get _isNotification => rule.trigger is NotificationTrigger;

  @override
  void initState() {
    super.initState();
    _action = rule.action;
    _message = TextEditingController(text: rule.message);
    _dynamicReply = rule.dynamicReply;
    final time = rule.trigger is TimeTrigger ? rule.trigger as TimeTrigger : null;
    _time = TimeOfDay(hour: time?.hour ?? 9, minute: time?.minute ?? 0);
    _weekdays = Set.of(time?.weekdays ?? const <int>{});
    final notif =
        rule.trigger is NotificationTrigger
            ? rule.trigger as NotificationTrigger
            : null;
    _contact = TextEditingController(text: notif?.senderMatch ?? '');
    _textMatch = TextEditingController(text: notif?.textMatch ?? '');
  }

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    _textMatch.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickMedia() async {
    // Misma API estática del chat y del creador de reglas (file_picker v11).
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    setState(() => _newMediaPath = file.path);
  }

  Future<void> _save() async {
    final Trigger trigger;
    if (_isTime) {
      trigger = TimeTrigger(
        hour: _time.hour,
        minute: _time.minute,
        weekdays: Set.of(_weekdays),
      );
    } else if (_isNotification) {
      trigger = NotificationTrigger(
        // El paquete se conserva: solo contacto y contenido se editan.
        packageName: (rule.trigger as NotificationTrigger).packageName,
        senderMatch: _contact.text.trim().isEmpty
            ? null
            : _contact.text.trim(),
        textMatch: _textMatch.text.trim().isEmpty
            ? null
            : _textMatch.text.trim(),
      );
    } else {
      // Conectividad/batería: sin productor de eventos todavía. Se conserva
      // el disparo tal cual (honesto: la UI no finge soporte).
      trigger = rule.trigger;
    }

    final needsSender =
        _action == RuleAction.reply || _action == RuleAction.sendMedia;
    if (trigger is TimeTrigger && needsSender) {
      setState(
        () => _error =
            'Responder y enviar archivos necesitan un remitente: con hora '
            'solo puedo avisarte. Usa un disparo de notificación.',
      );
      return;
    }

    // FIX-VERT-01 — mismo colapso que la creación: el mensaje editado se
    // guarda de una línea (saltos por pegado/dictado fuera).
    final message = _action == RuleAction.notify
        ? ''
        : _message.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    String? mediaPath;
    if (_action == RuleAction.sendMedia) {
      if (_newMediaPath == null &&
          (rule.mediaPath == null || rule.mediaPath!.isEmpty)) {
        setState(() => _error = 'Elige un archivo antes de guardar el envío.');
        return;
      }
      if (_newMediaPath != null) {
        // WA-MEDIA-01 — copia al catálogo ANTES de guardar: la regla apunta
        // a una ruta estable; sin copia exitosa no hay guardado (fail honesto).
        mediaPath = await const WhatsAppMediaShare().copyToCatalog(
          _newMediaPath!,
        );
        if (mediaPath == null) {
          setState(
            () => _error =
                'No se pudo copiar el archivo al catálogo. Intenta de nuevo.',
          );
          return;
        }
      } else {
        mediaPath = rule.mediaPath;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      ScheduledRule(
        id: rule.id,
        trigger: trigger,
        action: _action,
        message: message,
        dynamicReply: _action == RuleAction.reply && _dynamicReply,
        // null explícito: si la acción ya no envía archivo, se suelta el
        // viejo (copyWith no permite "limpiar" con null).
        mediaPath: mediaPath,
        enabled: rule.enabled,
        createdAt: rule.createdAt,
        lastFiredAt: rule.lastFiredAt,
        lastOutcome: rule.lastOutcome,
        createdByUser: rule.createdByUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:'
        '${_time.minute.toString().padLeft(2, '0')}';
    final mediaName = _newMediaPath == null
        ? (rule.mediaPath?.split('/').last ?? 'sin archivo')
        : _newMediaPath!.split('/').last;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Editar regla',
              style: TextStyle(
                color: visual.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID ${rule.id}',
              style: TextStyle(color: visual.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 20),
            if (_isTime) ...[
              const _FieldLabel('Hora'),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: visual.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: visual.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: visual.accent),
                      const SizedBox(width: 10),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: visual.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: visual.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Días (vacío = todos los días)'),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final day in const [
                    (1, 'Lun'),
                    (2, 'Mar'),
                    (3, 'Mié'),
                    (4, 'Jue'),
                    (5, 'Vie'),
                    (6, 'Sáb'),
                    (7, 'Dom'),
                  ])
                    FilterChip(
                      label: Text(day.$2),
                      selected: _weekdays.contains(day.$1),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _weekdays.add(day.$1);
                        } else {
                          _weekdays.remove(day.$1);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ] else if (_isNotification) ...[
              const _FieldLabel('Contacto (vacío = cualquier contacto)'),
              _EditorField(controller: _contact, hint: 'Juan'),
              const SizedBox(height: 12),
              const _FieldLabel('Contenido (vacío = cualquier texto)'),
              _EditorField(controller: _textMatch, hint: 'urgente'),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                'El disparo de esta regla aún no tiene editor: se conserva '
                'tal cual.',
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
            const _FieldLabel('Acción'),
            DropdownButtonFormField<RuleAction>(
              initialValue: _action,
              dropdownColor: visual.surface,
              style: TextStyle(color: visual.text, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: visual.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: visual.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: visual.outline),
                ),
              ),
              items: [
                for (final action in RuleAction.values)
                  DropdownMenuItem(value: action, child: Text(action.label)),
              ],
              onChanged: (a) => setState(() {
                if (a != null) _action = a;
              }),
            ),
            if (_action != RuleAction.notify) ...[
              const SizedBox(height: 12),
              _FieldLabel(
                _action == RuleAction.sendMedia
                    ? 'Texto del mensaje (caption)'
                    : 'Texto de la respuesta',
              ),
              _EditorField(
                controller: _message,
                hint: _action == RuleAction.sendMedia
                    ? 'Aquí tienes el catálogo'
                    : 'Estoy ocupado, te respondo luego',
                maxLines: 3,
              ),
            ],
            if (_action == RuleAction.reply) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _dynamicReply,
                onChanged: (v) =>
                    setState(() => _dynamicReply = v ?? _dynamicReply),
                title: const Text(
                  'Respuesta dinámica con IA local',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Sin texto fijo: el motor redacta según la conversación real.',
                  style: TextStyle(fontSize: 11),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
            if (_action == RuleAction.sendMedia) ...[
              const SizedBox(height: 12),
              const _FieldLabel('Archivo (catálogo fijo)'),
              InkWell(
                onTap: _pickMedia,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: visual.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: visual.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file_rounded, size: 18, color: visual.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mediaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visual.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Cambiar',
                        style: TextStyle(color: visual.accent, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: danger, fontSize: 12, height: 1.35),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: AutomationVisual.of(context).textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: visual.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: visual.textMuted, fontSize: 13),
        filled: true,
        fillColor: visual.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: visual.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: visual.outline),
        ),
      ),
    );
  }
}
