part of 'personalization_studio_screen.dart';

final class _StyleResult {
  const _StyleResult({
    required this.register,
    required this.relationship,
    required this.learn,
    required this.enabled,
    required this.slang,
    required this.usesName,
    required this.custom,
    required this.tone,
  });
  final String register, relationship, usesName, custom;
  final bool learn, enabled, slang;
  final ToneProfile tone;
}

final class _ExampleResult {
  const _ExampleResult({
    required this.scope,
    required this.body,
    required this.input,
    required this.verified,
    required this.enabled,
    required this.isTemplate,
  });
  final String scope, body, input;
  final bool verified, enabled, isTemplate;
}

final class _MemoryResult {
  const _MemoryResult({
    required this.scope,
    required this.key,
    required this.value,
    required this.kind,
    required this.observedAt,
    this.expiresAt,
    required this.enabled,
  });
  final String scope, key, value, kind;
  final DateTime observedAt;
  final DateTime? expiresAt;
  final bool enabled;
}

// ─────────────────────────────────────────────
// Dialog widgets (own their local state)
// ─────────────────────────────────────────────

class _StyleEditDialog extends StatefulWidget {
  const _StyleEditDialog({required this.scope, required this.existing});
  final _Scope scope;
  final Map<String, String> existing;

  @override
  State<_StyleEditDialog> createState() => _StyleEditDialogState();
}

class _StyleEditDialogState extends State<_StyleEditDialog> {
  late String register, relationship, usesName;
  late bool learn, enabled, slang;
  late ToneProfile tone;
  late final TextEditingController _custom;

  static const _registers = {'formal', 'casual', 'close', 'custom'};
  static const _relationships = {'known', 'close', 'family', 'professional'};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    register = _registers.contains(e['styleRegister'])
        ? e['styleRegister']!
        : 'casual';
    relationship = _relationships.contains(e['relationship'])
        ? e['relationship']!
        : 'known';
    learn = e['learnStyle'] != 'false';
    enabled = e['profileEnabled'] != 'false';
    slang = e['allowSlang'] == 'true';
    usesName = e['usesContactName'] == 'never' ? 'never' : 'natural';
    _custom = TextEditingController(text: e['customStyle'] ?? '');
    tone = const ToneProfile(enabled: true, verbosity: ToneVerbosity.breve);
    try {
      if (e['tone'] case final String raw) {
        tone = ToneProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (err) {
      debugPrint(
        '[PersonalizationStudio] Error decoding tone profile JSON: $err',
      );
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.scope.id == 'owner'
          ? 'Mi estilo global'
          : 'Estilo: ${widget.scope.label}',
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.scope.id != 'owner')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aplicar este perfil'),
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
            DropdownButtonFormField<String>(
              initialValue: register,
              decoration: const InputDecoration(labelText: 'Registro'),
              items: const [
                DropdownMenuItem(value: 'formal', child: Text('Formal')),
                DropdownMenuItem(
                  value: 'casual',
                  child: Text('Casual neutral'),
                ),
                DropdownMenuItem(value: 'close', child: Text('Cercano')),
                DropdownMenuItem(value: 'custom', child: Text('Personalizado')),
              ],
              onChanged: (v) => setState(() => register = v!),
            ),
            if (widget.scope.id != 'owner')
              DropdownButtonFormField<String>(
                initialValue: relationship,
                decoration: const InputDecoration(
                  labelText: 'Relación declarada',
                ),
                items: const [
                  DropdownMenuItem(value: 'known', child: Text('Conocido')),
                  DropdownMenuItem(
                    value: 'close',
                    child: Text('Amistad cercana'),
                  ),
                  DropdownMenuItem(value: 'family', child: Text('Familia')),
                  DropdownMenuItem(
                    value: 'professional',
                    child: Text('Profesional'),
                  ),
                ],
                onChanged: (v) => setState(() => relationship = v!),
              ),
            DropdownButtonFormField<ToneVerbosity>(
              initialValue: tone.verbosity,
              decoration: const InputDecoration(labelText: 'Longitud'),
              items: [
                for (final v in ToneVerbosity.values)
                  DropdownMenuItem(value: v, child: Text(v.name)),
              ],
              onChanged: (v) =>
                  setState(() => tone = tone.copyWith(verbosity: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emojis moderados'),
              value: tone.emojis,
              onChanged: (v) => setState(() => tone = tone.copyWith(emojis: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir vocabulario coloquial cuando encaje'),
              subtitle: const Text('Nunca fuerza slang; Formal lo excluye.'),
              value: slang,
              onChanged: (v) => setState(() => slang = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: usesName,
              decoration: const InputDecoration(labelText: 'Uso del nombre'),
              items: const [
                DropdownMenuItem(
                  value: 'natural',
                  child: Text('Solo cuando sea natural'),
                ),
                DropdownMenuItem(
                  value: 'never',
                  child: Text('No usarlo al saludar'),
                ),
              ],
              onChanged: (v) => setState(() => usesName = v!),
            ),
            if (widget.scope.id != 'owner')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar este contacto para mi estilo'),
                subtitle: const Text(
                  'Permite importar y recuperar sus ejemplos. Desactivarlo no borra datos.',
                ),
                value: learn,
                onChanged: (v) => setState(() => learn = v),
              ),
            TextField(
              controller: _custom,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Preferencias de forma',
                hintText: 'Breve, sin emojis, humor solo si encaja…',
              ),
            ),
            const Text(
              'El estilo no acredita ubicación, actividad, stock ni disponibilidad actuales.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _StyleResult(
            register: register,
            relationship: relationship,
            learn: learn,
            enabled: enabled,
            slang: slang,
            usesName: usesName,
            custom: _custom.text.trim(),
            tone: tone,
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _ExampleEditDialog extends StatefulWidget {
  const _ExampleEditDialog({
    required this.isTemplate,
    required this.initialScope,
    required this.scopes,
    required this.busy,
    this.example,
  });
  final PersonaExample? example;
  final bool isTemplate, busy;
  final String initialScope;
  final Map<String, _Scope> scopes;

  @override
  State<_ExampleEditDialog> createState() => _ExampleEditDialogState();
}

class _ExampleEditDialogState extends State<_ExampleEditDialog> {
  late final TextEditingController _incoming, _reply;
  late String scope;
  late bool verified, enabled;

  @override
  void initState() {
    super.initState();
    final e = widget.example;
    _incoming = TextEditingController(text: e?.incomingText ?? '');
    _reply = TextEditingController(text: e?.body ?? '');
    scope = widget.initialScope;
    verified = e?.ownerVerified ?? false;
    enabled = e?.enabled ?? true;
  }

  @override
  void dispose() {
    _incoming.dispose();
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.isTemplate ? 'Plantilla de orientación' : 'Ejemplo real del dueño',
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(scope),
              initialValue: widget.scopes.containsKey(scope) ? scope : 'owner',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Aplicar solamente a',
              ),
              items: [
                for (final s in widget.scopes.values)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: widget.busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => scope = v);
                    },
            ),
            TextField(
              controller: _incoming,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Qué me dijeron',
                helperText: 'Vacío = solo estilo, no par condicionado.',
              ),
            ),
            TextField(
              controller: _reply,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.isTemplate
                    ? 'Guía de respuesta'
                    : 'Qué respondí realmente',
              ),
            ),
            if (widget.isTemplate)
              const Text(
                'Variables sin datos reales no se rellenan. Una plantilla no prueba stock, precio ni estado actual.',
              ),
            if (!widget.isTemplate)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Esta respuesta la escribí yo; no es una salida de Nano',
                ),
                value: verified,
                onChanged: (v) => setState(() => verified = v!),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar al recuperar ejemplos'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: widget.isTemplate || verified
            ? () => Navigator.pop(
                context,
                _ExampleResult(
                  scope: scope,
                  body: _reply.text.trim(),
                  input: _incoming.text.trim(),
                  verified: verified,
                  enabled: enabled,
                  isTemplate: widget.isTemplate,
                ),
              )
            : null,
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _MemoryEditDialog extends StatefulWidget {
  const _MemoryEditDialog({
    required this.initialScope,
    required this.scopes,
    required this.busy,
    this.memory,
  });
  final PersonalMemory? memory;
  final String initialScope;
  final Map<String, _Scope> scopes;
  final bool busy;

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _key, _value, _observed, _expiry;
  late String kind, scope;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    final m = widget.memory;
    _key = TextEditingController(text: m?.key ?? '');
    _value = TextEditingController(text: m?.value ?? '');
    _observed = TextEditingController(
      text: DateTime.fromMillisecondsSinceEpoch(
        m?.observedAt ?? DateTime.now().millisecondsSinceEpoch,
      ).toIso8601String(),
    );
    _expiry = TextEditingController(
      text: m?.expiresAt == null
          ? ''
          : DateTime.fromMillisecondsSinceEpoch(
              m!.expiresAt!,
            ).toIso8601String(),
    );
    kind = personalMemoryKinds.containsKey(m?.kind)
        ? m!.kind
        : m == null
        ? 'stablePreference'
        : 'episodicMemory';
    scope = widget.initialScope;
    enabled = m?.enabled ?? true;
  }

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    _observed.dispose();
    _expiry.dispose();
    super.dispose();
  }

  void _submit() {
    final k = _key.text.trim(), v = _value.text.trim();
    final at = DateTime.tryParse(_observed.text);
    final until = _expiry.text.trim().isEmpty
        ? null
        : DateTime.tryParse(_expiry.text);
    if (k.isEmpty ||
        v.isEmpty ||
        at == null ||
        (_expiry.text.trim().isNotEmpty &&
            (until == null || !until.isAfter(at))) ||
        (kind == 'temporaryFact' && (until == null || !until.isAfter(at)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa la clave, valor y fechas válidas. Los datos temporales deben caducar después de observarse.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _MemoryResult(
        scope: scope,
        key: k,
        value: v,
        kind: kind,
        observedAt: at,
        expiresAt: until,
        enabled: enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Memoria personal'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(scope),
              initialValue: widget.scopes.containsKey(scope) ? scope : 'owner',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Aplicar solamente a',
              ),
              items: [
                for (final s in widget.scopes.values)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: widget.busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => scope = v);
                    },
            ),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Clasificación'),
              items: [
                for (final entry in personalMemoryKinds.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => kind = v!),
            ),
            TextField(
              controller: _key,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Asunto / clave'),
            ),
            TextField(
              controller: _value,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Dato declarado'),
            ),
            TextField(
              controller: _observed,
              decoration: const InputDecoration(
                labelText: 'Fecha de registro / observación (ISO)',
              ),
            ),
            TextField(
              controller: _expiry,
              decoration: InputDecoration(
                labelText: kind == 'temporaryFact'
                    ? 'Caduca (obligatorio, ISO)'
                    : 'Caduca (opcional, ISO)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Memoria activa'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            const Text(
              'Los recuerdos no prueban estado actual. Datos temporales y de negocio quedan para revisión; no sustituyen las fuentes actuales del negocio.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Guardar')),
    ],
  );
}

class _LearnBanner extends StatelessWidget {
  const _LearnBanner({required this.onImport});
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cómo aprende Nano de ti',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Importa un chat de WhatsApp → revisa candidatos → acepta los que quieras. '
            'Nano usa tus respuestas reales para imitar tu registro y tono. '
            'Ningún dato sale del dispositivo ni modifica el modelo.',
            style: TextStyle(fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_open_outlined, size: 16),
            label: const Text(
              'Importar historial',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _Scope {
  const _Scope(this.id, this.label, {this.profile, this.conversationId});
  final String id, label;
  final RelationshipProfile? profile;
  final String? conversationId;
}

final class _ImportSelection {
  const _ImportSelection(this.indices, this.ownerVerified);
  final Set<int> indices;
  final bool ownerVerified;
}

class _ImportReview extends StatefulWidget {
  const _ImportReview({required this.preview, required this.scopeLabel});
  final PersonaImportPreview preview;
  final String scopeLabel;
  @override
  State<_ImportReview> createState() => _ImportReviewState();
}

class _ImportReviewState extends State<_ImportReview> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.preview.candidates.length; i++) i,
  };
  bool _ownerVerified = false;
  @override
  Widget build(BuildContext context) {
    final needsOwner = _selected.any(
      (i) =>
          !{'template', 'memory'}.contains(widget.preview.candidates[i].kind),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar antes de guardar')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${widget.preview.fileName}\nDestino exclusivo: ${widget.scopeLabel}\n${widget.preview.candidates.length} candidatos; ${_selected.length} seleccionados. No se ha guardado nada.',
                  ),
                ),
                if (widget.preview.warnings.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      '${widget.preview.warnings.length} avisos de importación',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(widget.preview.warnings.join('\n')),
                      ),
                    ],
                  ),
                CheckboxListTile(
                  title: const Text('Seleccionar todos los candidatos'),
                  value:
                      widget.preview.candidates.isNotEmpty &&
                      _selected.length == widget.preview.candidates.length,
                  onChanged: widget.preview.candidates.isEmpty
                      ? null
                      : (v) => setState(() {
                          _selected.clear();
                          if (v == true) {
                            _selected.addAll(
                              List.generate(
                                widget.preview.candidates.length,
                                (i) => i,
                              ),
                            );
                          }
                        }),
                ),
                if (needsOwner)
                  CheckboxListTile(
                    title: const Text(
                      'Confirmo que las respuestas seleccionadas las escribí yo, no Nano ni otro asistente',
                    ),
                    value: _ownerVerified,
                    onChanged: (v) => setState(() => _ownerVerified = v!),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Al guardar, el original completo queda en este teléfono para revisar el origen. Solo se recuperan los registros aceptados.',
                  ),
                ),
                if (widget.preview.candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No se encontraron registros válidos. Revisa los avisos y el formato del archivo.',
                    ),
                  ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: widget.preview.candidates.length,
            itemBuilder: (context, i) {
              final candidate = widget.preview.candidates[i];
              return CheckboxListTile(
                value: _selected.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(i);
                  } else {
                    _selected.remove(i);
                  }
                }),
                title: Text(candidate.title),
                subtitle: Text(candidate.preview),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || (needsOwner && !_ownerVerified)
                ? null
                : () => Navigator.pop(
                    context,
                    _ImportSelection(Set.of(_selected), _ownerVerified),
                  ),
            icon: const Icon(Icons.save_outlined),
            label: Text('Guardar ${_selected.length} seleccionados'),
          ),
        ),
      ),
    );
  }
}
