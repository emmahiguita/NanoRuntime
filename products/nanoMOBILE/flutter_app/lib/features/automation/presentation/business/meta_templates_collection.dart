import 'package:flutter/material.dart';

import '../../engine/business/meta_template_models.dart';

/// Dibuja estados y lista sin asumir que borradores son recursos aprobados.
class MetaTemplatesCollection extends StatelessWidget {
  const MetaTemplatesCollection({
    super.key,
    required this.loading,
    required this.configured,
    required this.error,
    required this.templates,
    required this.onConfigure,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final bool loading;
  final bool configured;
  final String? error;
  final List<MetaMessageTemplate> templates;
  final VoidCallback onConfigure;
  final VoidCallback onRefresh;
  final ValueChanged<MetaMessageTemplate> onEdit;
  final ValueChanged<MetaMessageTemplate> onDelete;

  /// Traduce estados conocidos sin ocultar estados nuevos que Meta agregue.
  String _status(String value) => switch (value) {
    'APPROVED' => 'Aprobada',
    'PENDING' => 'Pendiente',
    'REJECTED' => 'Rechazada',
    'PAUSED' => 'Pausada',
    'DISABLED' => 'Desactivada',
    _ => value,
  };

  /// Adapta la presentación a portrait y landscape con desplazamiento seguro.
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 700;
    if (loading) return const Center(child: CircularProgressIndicator());
    if (!configured) {
      return _empty(
        context,
        Icons.cloud_off_outlined,
        'Conecta un servidor Nano configurado con Meta para ver recursos reales.',
        FilledButton.icon(
          onPressed: onConfigure,
          icon: const Icon(Icons.link),
          label: const Text('Configurar conexión'),
        ),
      );
    }
    if (error != null) {
      return _empty(
        context,
        Icons.error_outline,
        error!,
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (templates.isEmpty) {
      return _empty(
        context,
        Icons.mark_email_read_outlined,
        'Meta no devolvió plantillas para esta cuenta.',
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar'),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, wide ? 24 : 96),
      itemCount: templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _templateCard(templates[index]),
    );
  }

  /// Presenta identidad y estado oficial con acciones remotas explícitas.
  Widget _templateCard(MetaMessageTemplate item) => Card(
    child: ListTile(
      isThreeLine: true,
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_status(item.status)} · ${item.category} · ${item.language}\n${item.components.length} componentes',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'Editar en Meta',
            onPressed: () => onEdit(item),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar en Meta',
            onPressed: () => onDelete(item),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    ),
  );

  /// Mantiene estados vacíos cortos y centrados para pantallas estrechas.
  Widget _empty(
    BuildContext context,
    IconData icon,
    String message,
    Widget action,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          action,
        ],
      ),
    ),
  );
}
