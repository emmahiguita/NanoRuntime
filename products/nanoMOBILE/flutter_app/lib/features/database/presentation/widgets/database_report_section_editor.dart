// QUÉ: editor visual de las secciones que formarán el informe PDF.
// CÓMO: permite activar y reordenar cada bloque mediante arrastre real.
// POR QUÉ: el usuario controla el documento sin editar código ni datos.

import 'package:flutter/material.dart';
import '../../domain/report_section.dart';

class DatabaseReportSectionEditor extends StatelessWidget {
  final List<ReportSection> order;
  final Set<ReportSection> enabled;
  final ValueChanged<List<ReportSection>> onReorder;
  final ValueChanged<ReportSection> onToggle;

  const DatabaseReportSectionEditor({
    super.key,
    required this.order,
    required this.enabled,
    required this.onReorder,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Contenido del informe',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 2),
      Text(
        'Activa secciones y arrástralas para definir el orden del PDF.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: order.length,
        onReorder: _move,
        proxyDecorator: (child, _, animation) => FadeTransition(
          opacity: animation.drive(Tween(begin: 0.82, end: 1.0)),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        ),
        itemBuilder: (context, index) {
          final section = order[index];
          final selected = enabled.contains(section);
          final canDisable = !selected || enabled.length > 1;
          return Card(
            key: ValueKey(section),
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              dense: true,
              minVerticalPadding: 6,
              leading: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_indicator_rounded),
              ),
              title: Text(section.title, maxLines: 1),
              subtitle: Text(section.description, maxLines: 2),
              trailing: Checkbox(
                value: selected,
                onChanged: canDisable ? (_) => onToggle(section) : null,
              ),
              onTap: canDisable ? () => onToggle(section) : null,
            ),
          );
        },
      ),
    ],
  );

  // Ajusta el índice que entrega Flutter al mover hacia abajo en la lista.
  void _move(int oldIndex, int newIndex) {
    final updated = List<ReportSection>.of(order);
    if (newIndex > oldIndex) newIndex--;
    final section = updated.removeAt(oldIndex);
    updated.insert(newIndex, section);
    onReorder(updated);
  }
}
