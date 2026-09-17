part of 'personalization_studio_screen.dart';

extension _PersonalizationStudioActions on _PersonalizationStudioScreenState {
  Future<void> _run(
    Future<void> Function() action, {
    bool reload = true,
  }) async {
    if (!mounted || _busy) return;
    final personaContext = ref.read(personaContextProvider);
    _safeSetState(() => _busy = true);
    try {
      await action();
      await personaContext.refresh();
      if (reload) await _reload();
    } catch (error) {
      _notice('$error');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  void _selectScope(String scope) {
    if (!mounted || scope == _scope) return;
    _safeSetState(() {
      _scope = scope;
      _examples = [];
      _memories = [];
      _loading = true;
    });
    unawaited(_reload());
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ==
      true;
  Future<void> _editStyle(_Scope scope) async {
    final existing = scope.id == 'owner'
        ? _owner?.facts ?? <String, String>{}
        : scope.profile?.facts ?? <String, String>{};
    final result = await showDialog<_StyleResult>(
      context: context,
      builder: (_) => _StyleEditDialog(scope: scope, existing: existing),
    );
    if (result == null) return;
    await _run(() async {
      final facts = {
        ...existing,
        'styleRegister': result.register,
        'relationship': result.relationship,
        'learnStyle': '${result.learn}',
        'profileEnabled': '${result.enabled}',
        'allowSlang': '${result.slang}',
        'usesContactName': result.usesName,
        'customStyle': result.custom,
        'tone': jsonEncode(
          result.tone
              .copyWith(
                enabled: true,
                warmth: result.register == 'formal'
                    ? ToneWarmth.formal
                    : ToneWarmth.cercano,
              )
              .toJson(),
        ),
        if (scope.conversationId != null)
          'conversationId': scope.conversationId!,
      };
      final ok = scope.id == 'owner'
          ? await _repo.upsertPersona('owner', _owner?.displayName ?? '', facts)
          : await _repo.upsertRelationship(scope.id, scope.label, facts);
      if (!ok) throw StateError('No se pudo guardar el perfil.');
      _notice('Perfil guardado. Se aplica a los próximos turnos.');
    });
  }

  Future<void> _newContact() async {
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Preparar un contacto'),
        content: TextField(
          controller: name,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Nombre para reconocerlo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final label = name.text.trim();
    name.dispose();
    if (saved != true) return;
    if (label.isEmpty) {
      _notice('Escribe un nombre para reconocer el contacto.');
      return;
    }
    await _run(() async {
      final id = 'unbound:${DateTime.now().microsecondsSinceEpoch}';
      if (!await _repo.upsertRelationship(id, label, {
        'learnStyle': 'true',
        'relationship': 'known',
        'styleRegister': 'casual',
      })) {
        throw StateError('No se pudo crear el contacto.');
      }
      _scope = id;
      _notice(
        'Contacto creado. Vincúlalo a una conversación activa para aplicarlo.',
      );
    });
  }

  Future<void> _bind(_Scope source) async {
    final choices = _scopes.values
        .where(
          (s) =>
              s.conversationId != null &&
              s.id != source.id &&
              s.profile == null,
        )
        .toList();
    if (source.profile == null) {
      _notice(
        'Guarda primero el estilo de este contacto para poder vincularlo.',
      );
      return;
    }
    if (choices.isEmpty) {
      _notice(
        'Recibe una notificación del contacto. Solo se vinculan conversaciones con identidad estable y sin otro perfil.',
      );
      return;
    }
    final target = await showDialog<_Scope>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Vincular a una conversación real'),
        children: [
          for (final scope in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, scope),
              child: Text(scope.label),
            ),
        ],
      ),
    );
    if (target == null) return;
    await _run(() async {
      await _repo.bindRelationshipScope(
        source.id,
        target.id,
        target.conversationId!,
      );
      _scope = target.id;
      _notice('Perfil, ejemplos y memorias vinculados a esa conversación.');
    });
  }

  Future<void> _import() async {
    if (!mounted || _working) return;
    final scope = _scopes[_scope]!;
    if (scope.profile?.facts['learnStyle'] == 'false') {
      _notice(
        'Este contacto tiene desactivado el uso para aprendizaje. Cambia su perfil si quieres importarlo.',
      );
      return;
    }
    _safeSetState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'csv'],
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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Identificar mis respuestas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Se aplicará a: ${scope.label}'),
                  const Text(
                    'TXT de WhatsApp con fechas día/mes/año. Escribe tu nombre tal como aparece en el archivo.',
                  ),
                  TextField(
                    controller: ownerName,
                    decoration: const InputDecoration(
                      labelText: 'Mi nombre en la exportación',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Analizar'),
              ),
            ],
          ),
        );
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
          builder: (_) =>
              _ImportReview(preview: preview, scopeLabel: scope.label),
        ),
      );
      if (selection == null || !mounted) return;
      await _run(() async {
        final outcome = await _repo.importPersonalization(
          preview.accepted(
            selection.indices,
            ownerVerified: selection.ownerVerified,
          ),
        );
        _notice(
          '${outcome['added']} registros guardados; ${outcome['duplicates']} duplicados omitidos.',
        );
      });
    } catch (error) {
      _notice('No se importó: $error');
    } finally {
      _safeSetState(() => _importing = false);
    }
  }

  Future<void> _editExample({
    PersonaExample? example,
    bool template = false,
  }) async {
    final result = await showDialog<_ExampleResult>(
      context: context,
      builder: (_) => _ExampleEditDialog(
        example: example,
        isTemplate: example?.isTemplate ?? template,
        initialScope: example?.personaKey ?? _scope,
        scopes: _scopes,
        busy: _busy || _importing,
      ),
    );
    if (result == null) return;
    if (result.body.isEmpty) {
      _notice('Escribe la respuesta o la plantilla antes de guardar.');
      return;
    }
    await _run(() async {
      final tone = {
        ...?example?.tone,
        'enabled': '${result.enabled}',
        'sourceContact': example?.tone['sourceContact'] ?? result.scope,
        'observedAt':
            example?.tone['observedAt'] ??
            '${DateTime.now().millisecondsSinceEpoch}',
        'ownerVerified': '${result.verified}',
        'kind': result.isTemplate
            ? 'template'
            : result.input.isEmpty
            ? 'style'
            : 'paired',
      };
      if (example == null) {
        final success = await _repo.addExample(
          personaKey: result.scope,
          body: result.body,
          incomingText: result.input,
          tone: tone,
          source: result.isTemplate ? 'template' : 'manual',
        );
        if (!success) {
          throw StateError('No se pudo guardar el ejemplo.');
        }
      } else {
        await _repo.updateExample(
          example,
          body: result.body,
          incomingText: result.input,
          tone: tone,
          scopeKey: result.scope,
        );
      }
    });
  }

  Future<void> _editMemory([PersonalMemory? memory]) async {
    final result = await showDialog<_MemoryResult>(
      context: context,
      builder: (_) => _MemoryEditDialog(
        memory: memory,
        initialScope: memory?.scopeKey ?? _scope,
        scopes: _scopes,
        busy: _busy || _importing,
      ),
    );
    if (result == null) return;
    await _run(
      () => _repo.savePersonalMemory(
        PersonalMemory(
          id: memory?.id ?? -1,
          scopeKey: result.scope,
          key: result.key,
          value: result.value,
          kind: result.kind,
          observedAt: result.observedAt.millisecondsSinceEpoch,
          metadata: {
            ...?memory?.metadata,
            'source': memory?.metadata['source'] ?? 'manual',
            'ownerVerified': 'true',
            'sourceContact': memory?.metadata['sourceContact'] ?? result.scope,
            'enabled': '${result.enabled}',
            'expiresAt': result.expiresAt == null
                ? ''
                : '${result.expiresAt!.millisecondsSinceEpoch}',
          },
        ),
      ),
    );
  }

  Widget _scopeField(String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: _scopes.containsKey(value) ? value : 'owner',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Aplicar solamente a'),
        items: [
          for (final scope in _scopes.values)
            DropdownMenuItem(
              value: scope.id,
              child: Text(scope.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _busy || _importing
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      );

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
    final value = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (value == null) return 'Fecha no disponible';
    try {
      return '${DateTime.fromMillisecondsSinceEpoch(value)}';
    } on ArgumentError {
      return 'Fecha no disponible';
    }
  }

  void _formatHelp() {
    final sample = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'messages': [
        {
          'role': 'contact',
          'text': 'Hola, ¿cómo vas?',
          'timestamp': 1788793200000,
        },
        {
          'role': 'owner',
          'text': 'Bien, gracias. ¿Y tú?',
          'timestamp': 1788793201000,
        },
      ],
      'memories': [
        {
          'type': 'stablePreference',
          'key': 'contacto',
          'value': 'Prefiere mensajes breves',
          'observedAt': 1788793200000,
        },
      ],
      'templates': [
        {
          'incoming': 'Consulta de referencia',
          'reply': '¿Cuál referencia buscas?',
        },
      ],
    });
    _infoDialog(
      'Formatos de importación',
      SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JSON v1: un contacto por archivo. CSV: role,text,timestamp. TXT: exportación WhatsApp con tu nombre exacto. '
                'Máximo 2 MB, 5000 mensajes, 1000 candidatos por lote. El original queda guardado localmente.',
              ),
              const SizedBox(height: 12),
              SelectableText(sample),
            ],
          ),
        ),
      ),
      extraActions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: sample));
            _notice('Ejemplo JSON copiado.');
          },
          child: const Text('Copiar JSON'),
        ),
      ],
    );
  }

  void _infoDialog(
    String title,
    Widget content, {
    List<Widget>? extraActions,
  }) => showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        ...?extraActions,
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );

  void _showHowItLearns() => _infoDialog(
    '¿Cómo aprende Nano de ti?',
    const SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '1. Importa TXT/CSV/JSON de WhatsApp.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Nano extrae pares: mensaje recibido → tu respuesta.'),
            SizedBox(height: 8),
            Text(
              '2. Revisa y acepta solo los candidatos que quieras.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Nada se guarda sin tu confirmación explícita.'),
            SizedBox(height: 8),
            Text(
              '3. En cada respuesta futura el retriever recupera tus ejemplos.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Longitud, registro y tono son los que tú usaste. '
              'Ningún dato sale del dispositivo ni modifica el modelo.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    ),
  );

  void _showPrivacyNote() => _infoDialog(
    'Privacidad de datos',
    const SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Text(
          'Todo queda en el dispositivo. Nada se envía a servidores ni al proveedor del modelo. '
          'Ejemplos y memorias se guardan en SQLite local. Puedes eliminar cualquier registro '
          'desde las pestañas. Retirar un lote elimina solo sus registros, no datos manuales.',
        ),
      ),
    ),
  );
}
