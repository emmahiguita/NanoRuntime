part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-ACTIONS — Acciones Nucleares de Persistencia y Edición.
///
/// **QUÉ HACE:**
/// Gestiona operaciones asíncronas con refresco de contexto, creación de contactos,
/// cambio de ámbito (scope), edición de estilo, frases de EMMA y adición rápida de respuestas.
///
/// **CÓMO FUNCIONA:**
/// Envuelve cada acción en _run con bloqueo reactivo (_busy), invocando
/// PersonaRepository en SQLite y notificando al proveedor de Riverpod.
///
/// **POR QUÉ:**
/// Centraliza los comandos CRUD del agente cumpliendo SOLID y manteniendo
/// el código estrictamente menor a 200 líneas.
extension _PersonalizationStudioActions on _PersonalizationStudioScreenState {
  Future<void> _run(Future<void> Function() action, {bool reload = true}) async {
    if (!mounted || _busy) return;
    final personaContext = ref.read(personaContextProvider);
    _safeSetState(() => _busy = true);
    try {
      await action();
      await personaContext.refresh();
      if (reload) await _reload();
    } catch (error) {
      _notice('');
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

  Future<void> _editStyle(_Scope scope) async {
    final existing = scope.id == 'owner' ? _owner?.facts ?? <String, String>{} : scope.profile?.facts ?? <String, String>{};
    final res = await showDialog<_StyleResult>(context: context, builder: (_) => _StyleEditDialog(scope: scope, existing: existing));
    if (res == null) return;
    await _run(() async {
      final facts = {
        ...existing,
        'styleRegister': res.register,
        'relationship': res.relationship,
        'learnStyle': '${res.learn}',
        'profileEnabled': '${res.enabled}',
        'allowSlang': '${res.slang}',
        'usesContactName': res.usesName,
        'customStyle': res.custom,
        'tone': jsonEncode(res.tone.copyWith(enabled: true, warmth: res.register == 'formal' ? ToneWarmth.formal : ToneWarmth.cercano).toJson()),
        if (scope.conversationId != null) 'conversationId': scope.conversationId!,
      };
      final ok = scope.id == 'owner' ? await _repo.upsertPersona('owner', _owner?.displayName ?? '', facts) : await _repo.upsertRelationship(scope.id, scope.label, facts);
      if (!ok) throw StateError('No se pudo guardar el perfil.');
      _notice('Perfil guardado para EMMA.');
    });
  }

  Future<void> _newContact() async {
    final picked = await showDialog<dynamic>(context: context, builder: (_) => _WhatsAppContactPickerDialog(existingScopes: _scopes));
    if (picked == null) return;
    String label = '', phone = '', jid = '';
    bool isBiz = false;
    if (picked is WhatsAppContact) {
      label = picked.name.trim(); phone = picked.number.trim(); jid = picked.jid.trim(); isBiz = picked.isBusiness;
    } else if (picked == 'manual') {
      if (!mounted) return;
      final manual = await showDialog<String>(context: context, builder: (_) => const _SingleInputDialog(title: 'Preparar un contacto', labelText: 'Nombre', confirmText: 'Crear'));
      if (manual == null || manual.trim().isEmpty) return;
      label = manual.trim();
    }
    if (label.isEmpty) return;
    final id = phone.isNotEmpty ? 'unbound:wa_$phone' : 'unbound:${DateTime.now().microsecondsSinceEpoch}';
    final facts = <String, String>{
      'learnStyle': 'true', 'relationship': 'known', 'styleRegister': 'casual',
      if (phone.isNotEmpty) 'whatsapp': phone,
      if (jid.isNotEmpty) 'jid': jid,
      if (isBiz) 'isBusiness': 'true',
    };
    final newScope = _Scope(id, label, profile: RelationshipProfile(relationshipKey: id, displayName: label, facts: facts));
    _safeSetState(() { _scopes[id] = newScope; _scope = id; });
    await _run(() async {
      await _repo.upsertRelationship(id, label, facts);
      _notice('Contacto de WhatsApp "$label" preparado.');
    });
  }

  Future<void> _bind(_Scope source) async {
    final choices = _scopes.values.where((s) => s.conversationId != null && s.id != source.id && s.profile == null).toList();
    if (source.profile == null) { _notice('Guarda primero el estilo de este contacto.'); return; }
    if (choices.isEmpty) { _notice('Recibe un mensaje del contacto para identificarlo.'); return; }
    final target = await showDialog<_Scope>(
      context: context,
      builder: (d) => SimpleDialog(title: const Text('Vincular a conversación real'), children: [for (final s in choices) SimpleDialogOption(onPressed: () => Navigator.pop(d, s), child: Text(s.label))]),
    );
    if (target == null) return;
    await _run(() async {
      await _repo.bindRelationshipScope(source.id, target.id, target.conversationId!);
      _scope = target.id;
      _notice('Perfil y diálogos vinculados.');
    });
  }

  Future<void> _editExample({PersonaExample? example, bool template = false}) async {
    final res = await showDialog<_ExampleResult>(
      context: context,
      builder: (_) => _ExampleEditDialog(
        example: example,
        isTemplate: example?.isTemplate ?? template,
        initialScope: example?.personaKey ?? _scope,
        scopes: _scopes,
        busy: _busy || _importing,
      ),
    );
    if (res == null || res.body.isEmpty) return;
    await _run(() async {
      final tone = {
        ...?example?.tone,
        'enabled': '',
        'sourceContact': example?.tone['sourceContact'] ?? res.scope,
        'observedAt': example?.tone['observedAt'] ?? '',
        'ownerVerified': '',
        'kind': res.isTemplate ? 'template' : res.input.isEmpty ? 'style' : 'paired',
        if (res.title.isNotEmpty) 'title': res.title,
        if (res.category.isNotEmpty) 'category': res.category,
        if (res.incomingVariants.isNotEmpty) 'incomingVariants': jsonEncode(res.incomingVariants),
        if (res.variants.isNotEmpty) 'variants': jsonEncode(res.variants),
        if (res.responses.isNotEmpty) 'responses': jsonEncode(res.responses.map((r) => r.toMap()).toList()),
      };
      if (example == null) {
        await _repo.addExample(personaKey: res.scope, body: res.body, incomingText: res.input, tone: tone, source: res.isTemplate ? 'template' : 'manual');
      } else {
        await _repo.updateExample(example, body: res.body, incomingText: res.input, tone: tone, scopeKey: res.scope);
      }
      _notice(example == null ? '¡Frase aprendida para EMMA!' : 'Frase actualizada.');
    });
  }

  Future<void> _addResponseToExample(PersonaExample example) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _SingleInputDialog(
        title: 'Agregar respuesta a "${example.displayTrigger}"',
        labelText: 'Nueva respuesta posible',
        hintText: 'Escribe tu forma de responder',
        confirmText: 'Agregar',
        maxLines: 2,
        maxLength: 200,
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final trimmed = text.trim();
    await _run(() async {
      final currentOpts = [...example.responseOptions, PersonaResponseOption(text: trimmed)];
      final tone = {
        ...example.tone,
        'variants': jsonEncode(currentOpts.map((r) => r.text).toList()),
        'responses': jsonEncode(currentOpts.map((r) => r.toMap()).toList()),
      };
      await _repo.updateExample(example, tone: tone);
      _notice('✨ Respuesta agregada a "${example.displayTrigger}".');
    });
  }

  Future<void> _editMemory([PersonalMemory? memory]) async {
    final res = await showDialog<_MemoryResult>(
      context: context,
      builder: (_) => _MemoryEditDialog(memory: memory, initialScope: memory?.scopeKey ?? _scope, scopes: _scopes, busy: _busy || _importing),
    );
    if (res == null) return;
    await _run(() => _repo.savePersonalMemory(PersonalMemory(
      id: memory?.id ?? -1,
      scopeKey: res.scope,
      key: res.key,
      value: res.value,
      kind: res.kind,
      observedAt: res.observedAt.millisecondsSinceEpoch,
      metadata: {
        ...?memory?.metadata,
        'source': memory?.metadata['source'] ?? 'manual',
        'ownerVerified': 'true',
        'sourceContact': memory?.metadata['sourceContact'] ?? res.scope,
        'enabled': '',
        'expiresAt': res.expiresAt == null ? '' : '',
      },
    )));
  }
}
