part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-ACTIONS-IMPORT — Acciones de Importación y Lotes.
///
/// **QUÉ HACE:**
/// Orquesta la importación de historiales de WhatsApp (TXT/JSON/CSV),
/// la verificación de identidad del propietario y la revocación de lotes guardados.
///
/// **CÓMO FUNCIONA:**
/// Invoca FilePicker, valida tamaños (máximo 2 MB), parsea candidatos mediante
/// PersonaImportPipeline y despliega la pantalla de revisión _ImportReview.
///
/// **POR QUÉ:**
/// Separa la ingesta de archivos pesados y la gestión de lotes del resto
/// de acciones para garantizar código mantenible y menor a 200 líneas.
extension _PersonalizationStudioImportActions on _PersonalizationStudioScreenState {
  Future<void> _import() async {
    if (!mounted || _working) return;
    final scope = _scopes[_scope]!;
    if (scope.profile?.facts['learnStyle'] == 'false') {
      _notice('Este contacto tiene desactivado el uso para aprendizaje.');
      return;
    }
    _safeSetState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt', 'csv'],
        withData: false,
      );
      if (picked == null || !mounted) return;
      final selected = picked.files.single;
      if (selected.path == null) {
        _notice('El proveedor de archivos no entregó una copia local legible.');
        return;
      }
      final file = File(selected.path!);
      if (await file.length() > PersonaImportPipeline.maxBytes) {
        _notice('Máximo 2 MB por archivo. Divide el historial.');
        return;
      }
      if (!mounted) return;
      final ownerName = TextEditingController(text: _owner?.displayName ?? '');
      var name = ownerName.text;
      if (selected.extension?.toLowerCase() == 'txt') {
        final confirmed = await _askWhatsAppOwnerName(scope.label, ownerName);
        name = ownerName.text;
        ownerName.dispose();
        if (confirmed != true || !mounted) return;
        if (name.trim().isEmpty) {
          _notice('Escribe tu nombre exacto para identificar tus respuestas.');
          return;
        }
      } else {
        ownerName.dispose();
      }
      final content = await file.readAsString();
      if (!mounted) return;
      final preview = const PersonaImportPipeline().parse(
        content: content,
        fileName: selected.name,
        scopeKey: scope.id,
        ownerName: name,
      );
      if (!mounted) return;
      final selection = await Navigator.of(context).push<_ImportSelection>(
        MaterialPageRoute(
          builder: (_) => _ImportReview(preview: preview, scopeLabel: scope.label),
        ),
      );
      if (selection == null || !mounted) return;
      await _run(() async {
        final outcome = await _repo.importPersonalization(
          preview.accepted(selection.indices, ownerVerified: selection.ownerVerified),
        );
        _notice('${outcome['added'] ?? 0} registros guardados; ${outcome['duplicates'] ?? 0} duplicados.');
      });
    } catch (error) {
      _notice('No se importó: $error');
    } finally {
      _safeSetState(() => _importing = false);
    }
  }

  Future<bool?> _askWhatsAppOwnerName(String scopeLabel, TextEditingController ctrl) {
    return showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Identificar mis respuestas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Se aplicará a: $scopeLabel'),
              const Text('TXT de WhatsApp. Escribe tu nombre tal como aparece en el archivo.'),
              TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Mi nombre en la exportación')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Analizar')),
        ],
      ),
    );
  }

  Future<void> _deleteBatch(Map batch) async {
    if (await _confirm('Retirar lote importado', 'Se eliminarán los ejemplos y memorias de este lote.')) {
      await _run(() async {
        final count = await _repo.deleteImportBatch('${batch['batchId']}');
        _notice('$count registros del lote retirados.');
      });
    }
  }

  Future<void> _viewBatchOrigin(Map batch) async {
    await _run(() async {
      final history = await _repo.importHistory((batch['id'] as num).toInt());
      if (!mounted) return;
      if (history == null) {
        _notice('El historial original ya no está disponible.');
        return;
      }
      await _infoDialog(
        'Historial original local',
        SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(
              history.length > 100000
                  ? '\n\nVista limitada a 100000 caracteres.'
                  : history,
            ),
          ),
        ),
      );
    }, reload: false);
  }
}
