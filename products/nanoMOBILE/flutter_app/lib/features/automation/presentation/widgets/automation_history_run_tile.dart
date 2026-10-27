import 'package:flutter/material.dart';
import '../../ledger/automation_activity_event.dart';

/// Cronología de nodos observados: la flecha une registros existentes en orden
/// de inserción; no inventa pantallas ni acredita que una intención se cumplió.
class AutomationHistoryRunTile extends StatelessWidget {
  const AutomationHistoryRunTile({super.key, required this.events});
  final List<AutomationActivityEvent> events;

  static String stateLabel(String state) => switch (state) {
    'call' => 'Llamada iniciada',
    'resolved' => 'Identidad resuelta',
    'launch_requested' => 'Android aceptó la apertura',
    'waiting' => 'Esperando interfaz de WhatsApp',
    'clicked' => 'Clic de envío observado',
    'returned' => 'Regreso a Nano observado',
    'completed' => 'La herramienta informó finalización',
    'completedUnverified' => 'Finalizó con verificación parcial',
    'failed' || 'error' || 'exception' => 'No completado',
    'stopped' || 'cancelled' => 'Detenido',
    'timeoutOutcomeUnknown' ||
    'return_unverified' ||
    'outcomeUnknown' => 'Resultado incierto',
    _ => 'Resultado sin verificación suficiente',
  };

  @override
  Widget build(BuildContext context) {
    final first = events.first;
    final last = events.last;
    final time = DateTime.fromMillisecondsSinceEpoch(first.atMs).toLocal();
    final target = first.target.isEmpty ? 'Acción de Nano' : first.target;
    return ExpansionTile(
      key: PageStorageKey(first.runId),
      title: Text(target, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${time.day}/${time.month} · '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · '
        '${events.length} registros\n${stateLabel(last.state)}',
      ),
      children: [
        for (var i = 0; i < events.length; i++)
          ListTile(
            leading: Icon(
              i == 0 ? Icons.play_arrow_rounded : Icons.south_rounded,
              size: 20,
            ),
            title: Text(stateLabel(events[i].state)),
            subtitle: SelectableText('${events[i].route}\n${events[i].detail}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            'Ejecución: ${first.runId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
