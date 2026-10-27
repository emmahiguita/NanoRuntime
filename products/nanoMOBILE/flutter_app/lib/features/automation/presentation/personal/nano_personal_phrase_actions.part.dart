part of 'nano_personal_phrases_tab.dart';

// El editor modal posee sus controles; este módulo solo coordina persistencia.
extension NanoPersonalPhraseActions on _NanoPersonalPhrasesTabState {
  Future<void> _loadExamples() async {
    if (!mounted) return;
    try {
      final list = await PersonaRepository.instance.listExamples(
        scopeKey: 'owner',
      );
      if (!mounted) return;
      setState(() {
        _examples = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'No se pudieron cargar los diálogos.'; });
    }
  }

  Future<void> _toggleEnabled(PersonaExample ex, bool val) async {
    await _write(
      () => PersonaRepository.instance.updateExample(
        ex,
        tone: {...ex.tone, 'enabled': val ? 'true' : 'false'},
      ),
    );
  }

  Future<void> _addOrEditPhrase([PersonaExample? existing]) async {
    if (_writing) return;
    final ex = await NanoPersonalPhraseDialog.show(context, existing);
    if (ex == null || !mounted) return;
    await _write(() async {
      if (existing != null) {
        await PersonaRepository.instance.updateExample(
          existing,
          incomingText: ex.incomingText,
          body: ex.body,
          tone: ex.tone,
        );
      } else {
        final added = await PersonaRepository.instance.addExample(
          personaKey: 'owner',
          incomingText: ex.incomingText,
          body: ex.body,
          tone: ex.tone,
          source: 'manual',
        );
        if (!added) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo guardar la frase.')),
            );
          }
          return;
        }
      }
    });
  }

  // Reutiliza el editor que ya es dueño de sus controllers y de las variantes.
  Future<void> _addResponseQuickly(PersonaExample ex) => _addOrEditPhrase(ex);

  Future<void> _deletePhrase(PersonaExample ex) async {
    await _write(() async {
      if (!await PersonaRepository.instance.deleteExample(ex.id)) {
        throw StateError('No se pudo eliminar la frase');
      }
    });
  }

  // Serializa acciones visibles y captura fallos de SQLite sin falsos éxitos.
  Future<void> _write(Future<void> Function() action) async {
    if (!mounted || _writing) return;
    setState(() => _writing = true);
    try {
      await action();
      if (mounted) await _loadExamples();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el cambio en Frases.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }
}
