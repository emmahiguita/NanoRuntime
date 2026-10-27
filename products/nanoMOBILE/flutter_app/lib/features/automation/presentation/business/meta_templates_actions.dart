part of 'meta_templates_screen.dart';

/// Acciones remotas serializadas: un doble toque no crea dos plantillas.
/// La pantalla posee el cliente; al cerrarla se cancelan sus solicitudes HTTP.
extension _MetaTemplatesActions on _MetaTemplatesScreenState {
  Future<void> _mutate(Future<bool> Function() operation, String notice) async {
    if (!mounted || _mutating || _loading) return;
    setState(() => _mutating = true);
    try {
      final changed = await operation();
      if (!changed || !mounted) return;
      _notice(notice);
      await _load();
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  /// El borrador solo se envía si el usuario guarda y la pantalla sigue viva.
  Future<void> _edit([MetaMessageTemplate? template]) => _mutate(() async {
    final draft = await showDialog<MetaMessageTemplateDraft>(
      context: context,
      builder: (_) => MetaTemplateEditorDialog(initial: template),
    );
    if (draft == null || !mounted) return false;
    if (template == null) {
      await _api.create(draft);
    } else {
      await _api.update(template, draft);
    }
    return true;
  }, 'Meta recibió la solicitud. Consulta el estado tras actualizar.');

  /// Confirma el recurso exacto antes de borrar la plantilla remota.
  Future<void> _delete(MetaMessageTemplate template) => _mutate(() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar plantilla en Meta'),
        content: Text(
          'Se eliminará “${template.name}” de la cuenta conectada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return false;
    await _api.delete(template);
    return true;
  }, 'Meta confirmó la solicitud de eliminación.');
}
