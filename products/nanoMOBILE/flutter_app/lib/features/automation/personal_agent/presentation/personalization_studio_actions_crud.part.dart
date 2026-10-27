part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-ACTIONS-CRUD — Menú de ayuda, paginación y borrado.
extension _PersonalizationStudioCrudActions
    on _PersonalizationStudioScreenState {
  Map<dynamic, dynamic> _batchMetadata(dynamic raw) {
    if (raw is Map) return raw;
    if (raw is! String) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  String _batchDate(dynamic raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('');
    if (value == null) return 'Fecha no disponible';
    try {
      return '';
    } on ArgumentError {
      return 'Fecha no disponible';
    }
  }

  void _openHelpSheet() {
    showNanoGlassWindow<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('¿Cómo aprende Nano?'),
              onTap: () {
                Navigator.pop(ctx);
                _showHowItLearns();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.format_list_bulleted_rounded),
              title: const Text('Formatos de importación'),
              onTap: () {
                Navigator.pop(ctx);
                _formatHelp();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Privacidad de datos'),
              onTap: () {
                Navigator.pop(ctx);
                _showPrivacyNote();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExampleConfirmed(PersonaExample e) async {
    if (await _confirm(
      'Eliminar frase',
      'Dejará de usarse en las respuestas.',
    )) {
      await _run(() => _repo.deleteExample(e.id));
    }
  }

  Future<void> _loadMoreExamples() => _run(() async {
    final more = await _repo.listExamples(
      scopeKey: _scope,
      limit: 100,
      offset: _examples.length,
    );
    if (mounted) setState(() => _examples.addAll(more));
    if (more.isEmpty) _notice('No hay más frases.');
  }, reload: false);

  Future<void> _deleteContactConfirmed(_Scope c) async {
    if (await _confirm(
      'Eliminar perfil',
      'Se eliminará el perfil de ${c.label}.',
    )) {
      await _run(() => _repo.deleteRelationship(c.id));
    }
  }

  Future<void> _deleteMemoryConfirmed(PersonalMemory m) async {
    if (await _confirm(
      'Eliminar memoria',
      'El dato dejará de estar disponible.',
    )) {
      await _run(() => _repo.deletePersonalMemory(m.id));
    }
  }

  Future<void> _loadMoreMemories() => _run(() async {
    final more = await _repo.listPersonalMemories(
      scopeKey: _scope,
      limit: 100,
      offset: _memories.length,
    );
    if (mounted) setState(() => _memories.addAll(more));
    if (more.isEmpty) _notice('No hay más memorias.');
  }, reload: false);
}
