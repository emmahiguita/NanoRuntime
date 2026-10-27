import 'package:flutter/material.dart';
import '../../../../core/widgets/nano_glass_window.dart';
import '../../ledger/automation_activity_event.dart';
import '../../ledger/automation_activity_store.dart';
import 'automation_history_run_tile.dart';

/// Ventana de lectura sobre el registro SQLite existente. No reproduce acciones.
Future<void> showAutomationHistory(BuildContext context) =>
    showNanoGlassWindow<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      builder: (_) => const AutomationHistoryPanel(),
    );

class AutomationHistoryPanel extends StatefulWidget {
  const AutomationHistoryPanel({super.key});
  @override
  State<AutomationHistoryPanel> createState() => _AutomationHistoryPanelState();
}

class _AutomationHistoryPanelState extends State<AutomationHistoryPanel> {
  final _store = AutomationActivityStore.instance;
  late Future<List<AutomationActivityEvent>> _load;

  @override
  void initState() {
    super.initState();
    _load = _store.read();
    _store.revision.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() => _load = _store.read());
  }

  @override
  void dispose() {
    _store.revision.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de acciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Abre una ejecución para ver sus llamadas y observaciones reales.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      Flexible(
        child: FutureBuilder<List<AutomationActivityEvent>>(
          future: _load,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final groups = <String, List<AutomationActivityEvent>>{};
            for (final event in snapshot.data!) {
              (groups[event.runId] ??= []).add(event);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_store.persisted)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'El último cambio no se guardó. Se muestra la memoria de esta sesión.',
                    ),
                  ),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay llamadas registradas. Las nuevas acciones aparecerán aquí; no se reconstruye un pasado inexistente.',
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) => AutomationHistoryRunTile(
                        events: groups.values
                            .elementAt(index)
                            .reversed
                            .toList(),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
