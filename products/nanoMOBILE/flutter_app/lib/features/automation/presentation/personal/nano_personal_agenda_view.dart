import 'package:flutter/material.dart';
import '../../personal_agent/domain/personal_agenda_day.dart';

/// Presentación flexible del calendario y sus tramos, sin dependencias nuevas.
class NanoPersonalAgendaView extends StatelessWidget {
  const NanoPersonalAgendaView({
    super.key,
    required this.date,
    required this.entries,
    required this.notes,
    required this.enabled,
    required this.saving,
    required this.dirty,
    required this.status,
    required this.onDate,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onEnabled,
    required this.onNotes,
    required this.onSave,
    this.onDateSelected,
    this.repeatWeekly = false,
    this.calendarRevision = 0,
    this.onRepeatWeekly,
  });
  final DateTime date;
  final List<PersonalAgendaEntry> entries;
  final TextEditingController notes;
  final bool enabled, saving, dirty;
  final String? status;
  final VoidCallback onDate, onAdd, onSave;
  final ValueChanged<int> onEdit, onDelete;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<String> onNotes;
  final ValueChanged<DateTime>? onDateSelected;
  final bool repeatWeekly;
  final int calendarRevision;
  final ValueChanged<bool>? onRepeatWeekly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(date);
    final day = PersonalAgendaDay(entries: entries);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mi calendario y horarios',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (onDateSelected != null)
              CalendarDatePicker(
                key: ValueKey('$date|$calendarRevision'),
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateChanged: (value) {
                  if (!saving) onDateSelected!(value);
                },
              )
            else
              OutlinedButton.icon(
                onPressed: saving ? null : onDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(dateLabel),
              ),
            const Text(
              'Elige una fecha y añade tus actividades con hora de inicio y fin. Se usa la hora local del teléfono.',
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Sin actividades por horas para esta fecha.'),
              ),
            for (var index = 0; index < entries.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entries[index].title),
                subtitle: Text(
                  day.segmentsFor(entries[index]).isEmpty
                      ? 'Turno cubierto por pausas de comida'
                      : day
                            .segmentsFor(entries[index])
                            .map(
                              (entry) =>
                                  '${PersonalAgendaEntry.clock(entry.start)} – ${PersonalAgendaEntry.clock(entry.end)}',
                            )
                            .join(' / '),
                ),
                onTap: saving ? null : () => onEdit(index),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar actividad',
                      onPressed: saving ? null : () => onEdit(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Eliminar actividad',
                      onPressed: saving ? null : () => onDelete(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: saving ? null : onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir actividad'),
            ),
            const Text(
              'Añade desayuno, almuerzo y cena con tus horas reales. '
              'Esas pausas tienen prioridad dentro del turno de trabajo; '
              'al editar el trabajo conservas el inicio y fin originales.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              enabled: !saving,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              onChanged: onNotes,
              decoration: const InputDecoration(
                labelText: 'Notas para esta fecha',
                hintText: 'Información adicional que quieras compartir.',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: saving ? null : onEnabled,
              title: const Text('Usar esta fecha al responder a mis contactos'),
            ),
            if (onRepeatWeekly != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: repeatWeekly,
                title: const Text('Repetir este horario cada semana'),
                subtitle: const Text(
                  'En el mismo día de la semana de la fecha seleccionada.',
                ),
                onChanged: saving ? null : onRepeatWeekly,
              ),
            const Text(
              'Un horario vacío no significa que estés libre ni autoriza a aceptar invitaciones.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Guardando…' : 'Guardar agenda'),
            ),
            if (dirty) const Text('Tienes cambios sin guardar.'),
            if (status != null) Text(status!),
          ],
        ),
      ),
    );
  }
}
