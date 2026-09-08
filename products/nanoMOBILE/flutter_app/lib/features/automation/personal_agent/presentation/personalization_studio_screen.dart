import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../engine/messaging/tone_profile.dart';
import '../../engine/notifications/notification_object.dart';
import '../application/persona_context.dart';
import '../application/persona_import.dart';
import '../application/persona_repository.dart';
import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import '../domain/personal_memory.dart';

class PersonalizationStudioScreen extends ConsumerStatefulWidget {
  const PersonalizationStudioScreen({super.key});
  @override
  ConsumerState<PersonalizationStudioScreen> createState() =>
      _PersonalizationStudioScreenState();
}

class _PersonalizationStudioScreenState
    extends ConsumerState<PersonalizationStudioScreen> {
  final _repo = PersonaRepository.instance;
  String _scope = 'owner';
  String? _error;
  bool _busy = false, _loading = true, _importing = false;
  int _reloadGeneration = 0;
  bool get _working => _busy || _loading || _importing;
  bool get _canEdit => !_working && _error == null;
  Map<String, _Scope> _scopes = {
    'owner': const _Scope('owner', 'Estilo global del dueño'),
  };
  Map<String, dynamic> _summary = {};
  PersonaProfile? _owner;
  List<PersonaExample> _examples = [];
  List<PersonalMemory> _memories = [];
  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final generation = ++_reloadGeneration;
    final requestedScope = _scope;
    setState(() => _loading = true);
    try {
      final summary = await _repo.personalizationSummary();
      final profiles = await _repo.listRelationships();
      final owners = await _repo.listPersonas();
      final active = await NanoRuntimeApi.instance.listNotifications(
        limit: 100,
      );
      final scopes = <String, _Scope>{
        'owner': const _Scope('owner', 'Estilo global del dueño'),
        'role:personal': const _Scope(
          'role:personal',
          'Rol: conversación personal',
        ),
        'role:sales': const _Scope('role:sales', 'Rol: ventas / negocio'),
        'role:support': const _Scope('role:support', 'Rol: soporte'),
      };
      for (final profile in profiles) {
        scopes[profile.relationshipKey] = _Scope(
          profile.relationshipKey,
          profile.displayName,
          profile: profile,
          conversationId: profile.facts['conversationId'],
        );
      }
      for (final key
          in (summary['scopeKeys'] as List? ?? const []).whereType<String>()) {
        if (key.isEmpty || scopes.containsKey(key)) continue;
        final previous = _scopes[key];
        scopes[key] = _Scope(
          key,
          previous?.label ??
              'Datos sin perfil · ${key.length > 24 ? key.substring(0, 24) : key}',
          conversationId: previous?.conversationId,
        );
      }
      for (final row in active) {
        final notification = NotificationObject.fromMap(row);
        final identity = resolveConversationIdentity(notification);
        if (!identity.safeToWrite ||
            identity.key.id.isEmpty ||
            !notification.canReply) {
          continue;
        }
        final key = personalizationScope(identity.key.id);
        final label = notification.isGroup
            ? notification.conversationTitle
            : notification.sender;
        if (label.isEmpty) continue;
        scopes[key] = _Scope(
          key,
          '$label · ${notification.packageName}',
          conversationId: identity.key.id,
          profile: scopes[key]?.profile,
        );
      }
      final selected = scopes.containsKey(requestedScope)
          ? requestedScope
          : 'owner';
      final examples = await _repo.listExamples(limit: 100, scopeKey: selected);
      final memories = await _repo.listPersonalMemories(
        scopeKey: selected,
        limit: 100,
      );
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _summary = summary;
        _scopes = scopes;
        _scope = selected;
        _owner = owners.where((o) => o.personaKey == 'owner').firstOrNull;
        _examples = examples;
        _memories = memories;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _reloadGeneration) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool reload = true,
  }) async {
    if (!mounted || _busy) return;
    final personaContext = ref.read(personaContextProvider);
    setState(() => _busy = true);
    try {
      await action();
      await personaContext.refresh();
      if (reload) await _reload();
    } catch (error) {
      _notice('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectScope(String scope) {
    if (!mounted || scope == _scope) return;
    setState(() {
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
    var register =
        {
          'formal',
          'casual',
          'close',
          'custom',
        }.contains(existing['styleRegister'])
        ? existing['styleRegister']!
        : 'casual';
    var relationship =
        {
          'known',
          'close',
          'family',
          'professional',
        }.contains(existing['relationship'])
        ? existing['relationship']!
        : 'known';
    var learn = existing['learnStyle'] != 'false',
        enabled = existing['profileEnabled'] != 'false',
        slang = existing['allowSlang'] == 'true';
    var usesName = existing['usesContactName'] == 'never' ? 'never' : 'natural';
    var tone = const ToneProfile(enabled: true, verbosity: ToneVerbosity.breve);
    try {
      if (existing['tone'] case final String raw) {
        tone = ToneProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    final custom = TextEditingController(text: existing['customStyle'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            scope.id == 'owner' ? 'Mi estilo global' : 'Estilo: ${scope.label}',
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scope.id != 'owner')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aplicar este perfil'),
                      value: enabled,
                      onChanged: (v) => update(() => enabled = v),
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
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Personalizado'),
                      ),
                    ],
                    onChanged: (v) => update(() => register = v!),
                  ),
                  if (scope.id != 'owner')
                    DropdownButtonFormField<String>(
                      initialValue: relationship,
                      decoration: const InputDecoration(
                        labelText: 'Relación declarada',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'known',
                          child: Text('Conocido'),
                        ),
                        DropdownMenuItem(
                          value: 'close',
                          child: Text('Amistad cercana'),
                        ),
                        DropdownMenuItem(
                          value: 'family',
                          child: Text('Familia'),
                        ),
                        DropdownMenuItem(
                          value: 'professional',
                          child: Text('Profesional'),
                        ),
                      ],
                      onChanged: (v) => update(() => relationship = v!),
                    ),
                  DropdownButtonFormField<ToneVerbosity>(
                    initialValue: tone.verbosity,
                    decoration: const InputDecoration(labelText: 'Longitud'),
                    items: [
                      for (final v in ToneVerbosity.values)
                        DropdownMenuItem(value: v, child: Text(v.name)),
                    ],
                    onChanged: (v) =>
                        update(() => tone = tone.copyWith(verbosity: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Emojis moderados'),
                    value: tone.emojis,
                    onChanged: (v) =>
                        update(() => tone = tone.copyWith(emojis: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Permitir vocabulario coloquial cuando encaje',
                    ),
                    subtitle: const Text(
                      'Nunca fuerza slang; Formal lo excluye.',
                    ),
                    value: slang,
                    onChanged: (v) => update(() => slang = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: usesName,
                    decoration: const InputDecoration(
                      labelText: 'Uso del nombre',
                    ),
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
                    onChanged: (v) => update(() => usesName = v!),
                  ),
                  if (scope.id != 'owner')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usar este contacto para mi estilo'),
                      subtitle: const Text(
                        'Permite importar y recuperar sus ejemplos. Desactivarlo no borra datos.',
                      ),
                      value: learn,
                      onChanged: (v) => update(() => learn = v),
                    ),
                  TextField(
                    controller: custom,
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
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final customText = custom.text.trim();
    custom.dispose();
    if (saved != true) return;
    await _run(() async {
      final facts = {
        ...existing,
        'styleRegister': register,
        'relationship': relationship,
        'learnStyle': '$learn',
        'profileEnabled': '$enabled',
        'allowSlang': '$slang',
        'usesContactName': usesName,
        'customStyle': customText,
        'tone': jsonEncode(
          tone
              .copyWith(
                enabled: true,
                warmth: register == 'formal'
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
    setState(() => _importing = true);
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
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _editExample({
    PersonaExample? example,
    bool template = false,
  }) async {
    final incoming = TextEditingController(text: example?.incomingText ?? ''),
        reply = TextEditingController(text: example?.body ?? '');
    var scope = example?.personaKey ?? _scope,
        verified = example?.ownerVerified ?? false,
        enabled = example?.enabled ?? true;
    final isTemplate = example?.isTemplate ?? template;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            isTemplate ? 'Plantilla de orientación' : 'Ejemplo real del dueño',
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _scopeField(scope, (value) => update(() => scope = value)),
                  TextField(
                    controller: incoming,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Qué me dijeron',
                      helperText: 'Vacío = solo estilo, no par condicionado.',
                    ),
                  ),
                  TextField(
                    controller: reply,
                    maxLength: 2000,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: isTemplate
                          ? 'Guía de respuesta'
                          : 'Qué respondí realmente',
                    ),
                  ),
                  if (isTemplate)
                    const Text(
                      'Variables sin datos reales no se rellenan. Una plantilla no prueba stock, precio ni estado actual.',
                    ),
                  if (!isTemplate)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Esta respuesta la escribí yo; no es una salida de Nano',
                      ),
                      value: verified,
                      onChanged: (v) => update(() => verified = v!),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar al recuperar ejemplos'),
                    value: enabled,
                    onChanged: (v) => update(() => enabled = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isTemplate || verified
                  ? () => Navigator.pop(dialog, true)
                  : null,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final body = reply.text.trim(), input = incoming.text.trim();
    incoming.dispose();
    reply.dispose();
    if (saved != true) return;
    if (body.isEmpty) {
      _notice('Escribe la respuesta o la plantilla antes de guardar.');
      return;
    }
    await _run(() async {
      final tone = {
        ...?example?.tone,
        'enabled': '$enabled',
        'sourceContact': example?.tone['sourceContact'] ?? scope,
        'observedAt':
            example?.tone['observedAt'] ??
            '${DateTime.now().millisecondsSinceEpoch}',
        'ownerVerified': '$verified',
        'kind': isTemplate
            ? 'template'
            : input.isEmpty
            ? 'style'
            : 'paired',
      };
      if (example == null) {
        if (!await _repo.addExample(
          personaKey: scope,
          body: body,
          incomingText: input,
          tone: tone,
          source: isTemplate ? 'template' : 'manual',
        )) {
          throw StateError('No se pudo guardar el ejemplo.');
        }
      } else {
        await _repo.updateExample(
          example,
          body: body,
          incomingText: input,
          tone: tone,
          scopeKey: scope,
        );
      }
    });
  }

  Future<void> _editMemory([PersonalMemory? memory]) async {
    final key = TextEditingController(text: memory?.key ?? ''),
        value = TextEditingController(text: memory?.value ?? '');
    final observed = TextEditingController(
      text: DateTime.fromMillisecondsSinceEpoch(
        memory?.observedAt ?? DateTime.now().millisecondsSinceEpoch,
      ).toIso8601String(),
    );
    final expiry = TextEditingController(
      text: memory?.expiresAt == null
          ? ''
          : DateTime.fromMillisecondsSinceEpoch(
              memory!.expiresAt!,
            ).toIso8601String(),
    );
    var kind = personalMemoryKinds.containsKey(memory?.kind)
            ? memory!.kind
            : memory == null
            ? 'stablePreference'
            : 'episodicMemory',
        scope = memory?.scopeKey ?? _scope;
    var enabled = memory?.enabled ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Memoria personal'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _scopeField(scope, (v) => update(() => scope = v)),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(
                      labelText: 'Clasificación',
                    ),
                    items: [
                      for (final entry in personalMemoryKinds.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (v) => update(() => kind = v!),
                  ),
                  TextField(
                    controller: key,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Asunto / clave',
                    ),
                  ),
                  TextField(
                    controller: value,
                    maxLength: 2000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Dato declarado',
                    ),
                  ),
                  TextField(
                    controller: observed,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de registro / observación (ISO)',
                    ),
                  ),
                  TextField(
                    controller: expiry,
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
                    onChanged: (v) => update(() => enabled = v),
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
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final k = key.text.trim(),
        v = value.text.trim(),
        at = DateTime.tryParse(observed.text),
        until = expiry.text.trim().isEmpty
            ? null
            : DateTime.tryParse(expiry.text);
    final hadExpiry = expiry.text.trim().isNotEmpty;
    key.dispose();
    value.dispose();
    observed.dispose();
    expiry.dispose();
    if (saved != true) return;
    if (k.isEmpty ||
        v.isEmpty ||
        at == null ||
        (hadExpiry && (until == null || !until.isAfter(at))) ||
        (kind == 'temporaryFact' && (until == null || !until.isAfter(at)))) {
      _notice(
        'Completa la clave, valor y fechas válidas. Los datos temporales deben caducar después de observarse.',
      );
      return;
    }
    await _run(
      () => _repo.savePersonalMemory(
        PersonalMemory(
          id: memory?.id ?? -1,
          scopeKey: scope,
          key: k,
          value: v,
          kind: kind,
          observedAt: at.millisecondsSinceEpoch,
          metadata: {
            ...?memory?.metadata,
            'source': memory?.metadata['source'] ?? 'manual',
            'ownerVerified': 'true',
            'sourceContact': memory?.metadata['sourceContact'] ?? scope,
            'enabled': '$enabled',
            'expiresAt': until == null ? '' : '${until.millisecondsSinceEpoch}',
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
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Formatos de importación'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JSON v1: un contacto por archivo. CSV: role,text,timestamp; roles owner/contact. Fechas ISO o Unix en milisegundos. TXT: exportación WhatsApp día/mes/año, indicando tu nombre exacto. Máximo 2 MB, 5000 mensajes y 1000 candidatos por lote.\n\nSolo se activan los registros que aceptes. El archivo original completo se conserva localmente para revisar el origen. No se modifican pesos ni se suben historiales.',
                ),
                const SizedBox(height: 12),
                SelectableText(sample),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: sample));
              _notice('Ejemplo JSON copiado.');
            },
            child: const Text('Copiar JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _scopes.values
        .where((s) => s.id != 'owner' && !s.id.startsWith('role:'))
        .toList();
    final batches = (_summary['batches'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aprender de mis conversaciones'),
          actions: [
            IconButton(
              tooltip: 'Formatos y privacidad',
              onPressed: _formatHelp,
              icon: const Icon(Icons.help_outline),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Contactos'),
              Tab(text: 'Ejemplos'),
              Tab(text: 'Memorias'),
              Tab(text: 'Importaciones'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_working) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No se pudo leer la personalización: $_error'),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in {
                        'examples': 'Ejemplos',
                        'contacts': 'Contactos',
                        'memories': 'Memorias',
                        'templates': 'Plantillas',
                      }.entries)
                        Chip(
                          label: Text(
                            '${entry.value}: ${_summary[entry.key] ?? 0}',
                          ),
                        ),
                    ],
                  ),
                  _scopeField(_scope, _selectScope),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: !_canEdit
                              ? null
                              : () => _editStyle(_scopes[_scope]!),
                          icon: const Icon(Icons.tune),
                          label: const Text('Configurar estilo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _busy || _importing ? null : _reload,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    children: [
                      const Text(
                        'Solo las conversaciones vinculadas reciben su estilo. Si falta un contacto, recibe un mensaje suyo para obtener su identidad. Los nombres iguales no comparten perfil.',
                      ),
                      TextButton.icon(
                        onPressed: !_canEdit ? null : _newContact,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text(
                          'Preparar contacto sin conversación activa',
                        ),
                      ),
                      for (final contact in contacts)
                        Card(
                          child: ListTile(
                            title: Text(contact.label),
                            subtitle: Text(
                              '${contact.id.startsWith('contact:') ? 'Vinculado' : 'Sin vincular'} · ${contact.profile?.facts['styleRegister'] ?? 'neutral'} · ${contact.profile?.facts['learnStyle'] == 'false' ? 'No usar para estilo' : 'Importación permitida'}',
                            ),
                            onTap: !_canEdit
                                ? null
                                : () {
                                    _selectScope(contact.id);
                                    unawaited(_editStyle(contact));
                                  },
                            trailing: PopupMenuButton<String>(
                              enabled: _canEdit,
                              onSelected: (action) async {
                                if (action == 'bind') {
                                  await _bind(contact);
                                }
                                if (action == 'delete' &&
                                    await _confirm(
                                      'Eliminar perfil',
                                      'Se elimina el perfil de ${contact.label}. Sus ejemplos y memorias permanecen visibles hasta que los elimines.',
                                    )) {
                                  await _run(() async {
                                    if (!await _repo.deleteRelationship(
                                      contact.id,
                                    )) {
                                      throw StateError(
                                        'No se eliminó el perfil.',
                                      );
                                    }
                                  });
                                }
                              },
                              itemBuilder: (_) => [
                                if (!contact.id.startsWith('contact:'))
                                  const PopupMenuItem(
                                    value: 'bind',
                                    child: Text('Vincular a conversación'),
                                  ),
                                if (contact.profile != null)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar perfil'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: !_canEdit ? null : () => _editExample(),
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Ejemplo real'),
                          ),
                          TextButton.icon(
                            onPressed: !_canEdit
                                ? null
                                : () => _editExample(template: true),
                            icon: const Icon(Icons.view_quilt_outlined),
                            label: const Text('Plantilla'),
                          ),
                        ],
                      ),
                      if (_examples.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Sin ejemplos guardados para este ámbito. Importa y revisa una conversación o agrega uno manualmente.',
                          ),
                        ),
                      for (final example in _examples)
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  example.isTemplate
                                      ? 'Plantilla'
                                      : example.isPaired
                                      ? 'Par real'
                                      : 'Solo estilo',
                                ),
                                subtitle: Text(
                                  '${example.enabled ? 'Activo' : 'Desactivado'} · ${example.source}${example.ownerVerified
                                      ? ' · autoría confirmada'
                                      : example.isTemplate
                                      ? ' · orientación'
                                      : ' · requiere confirmar autoría'}',
                                ),
                                trailing: Switch(
                                  value: example.enabled,
                                  onChanged: !_canEdit
                                      ? null
                                      : (v) => _run(
                                          () => _repo.updateExample(
                                            example,
                                            tone: {
                                              ...example.tone,
                                              'enabled': '$v',
                                            },
                                          ),
                                        ),
                                ),
                              ),
                              if (example.incomingText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'Recibido: ${example.incomingText}',
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text('Respuesta: ${example.body}'),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: !_canEdit
                                        ? null
                                        : () => _editExample(example: example),
                                    child: const Text('Editar'),
                                  ),
                                  TextButton(
                                    onPressed: !_canEdit
                                        ? null
                                        : () async {
                                            if (await _confirm(
                                              'Eliminar ejemplo',
                                              'Dejará de usarse en la recuperación.',
                                            )) {
                                              await _run(() async {
                                                if (!await _repo.deleteExample(
                                                  example.id,
                                                )) {
                                                  throw StateError(
                                                    'No se eliminó.',
                                                  );
                                                }
                                              });
                                            }
                                          },
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (_examples.length >= 100)
                        TextButton(
                          onPressed: !_canEdit
                              ? null
                              : () => _run(() async {
                                  final more = await _repo.listExamples(
                                    scopeKey: _scope,
                                    limit: 100,
                                    offset: _examples.length,
                                  );
                                  if (mounted) {
                                    setState(() => _examples.addAll(more));
                                  }
                                  if (more.isEmpty) {
                                    _notice('No hay más ejemplos.');
                                  }
                                }, reload: false),
                          child: const Text('Cargar más ejemplos'),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    children: [
                      TextButton.icon(
                        onPressed: !_canEdit ? null : () => _editMemory(),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Agregar memoria'),
                      ),
                      if (_memories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Sin memorias declaradas. Los hechos históricos no se convierten en estado actual.',
                          ),
                        ),
                      for (final memory in _memories)
                        Card(
                          child: ListTile(
                            title: Text('${memory.key}: ${memory.value}'),
                            subtitle: Text(
                              '${personalMemoryKinds[memory.kind] ?? memory.kind} · ${memory.enabled
                                  ? memory.expired
                                        ? 'Caducada'
                                        : 'Activa'
                                  : 'Desactivada'} · ${_scopes[memory.scopeKey]?.label ?? memory.scopeKey}',
                            ),
                            onTap: !_canEdit ? null : () => _editMemory(memory),
                            trailing: PopupMenuButton<String>(
                              enabled: _canEdit,
                              onSelected: (action) async {
                                if (action == 'toggle') {
                                  await _run(
                                    () => _repo.savePersonalMemory(
                                      memory.copyWith(
                                        metadata: {
                                          ...memory.metadata,
                                          'enabled': '${!memory.enabled}',
                                        },
                                      ),
                                    ),
                                  );
                                }
                                if (action == 'delete' &&
                                    await _confirm(
                                      'Eliminar memoria',
                                      'El dato dejará de estar disponible para las respuestas.',
                                    )) {
                                  await _run(
                                    () => _repo.deletePersonalMemory(memory.id),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    memory.enabled ? 'Desactivar' : 'Activar',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_memories.length >= 100)
                        TextButton(
                          onPressed: !_canEdit
                              ? null
                              : () => _run(() async {
                                  final more = await _repo.listPersonalMemories(
                                    scopeKey: _scope,
                                    limit: 100,
                                    offset: _memories.length,
                                  );
                                  if (mounted) {
                                    setState(() => _memories.addAll(more));
                                  }
                                  if (more.isEmpty) {
                                    _notice('No hay más memorias.');
                                  }
                                }, reload: false),
                          child: const Text('Cargar más memorias'),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    children: [
                      const Text(
                        'Hasta 100 lotes recientes guardados localmente. No se han entrenado pesos. Retirar un lote elimina solo sus registros importados y su copia de historial.',
                      ),
                      if (batches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Todavía no has aceptado ninguna importación.',
                          ),
                        ),
                      for (final batch in batches)
                        Builder(
                          builder: (context) {
                            final metadata = _batchMetadata(batch['metadata']);
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${metadata['fileName'] ?? 'Importación'}',
                                ),
                                subtitle: Text(
                                  '${_batchDate(batch['atMs'])} · ${metadata['accepted'] ?? 'Cantidad desconocida'} aceptados',
                                ),
                                trailing: PopupMenuButton<String>(
                                  enabled: _canEdit,
                                  onSelected: (action) async {
                                    if (action == 'delete' &&
                                        await _confirm(
                                          'Retirar lote importado',
                                          'Se eliminarán los ejemplos y memorias de este lote, incluidos los editados después. No elimina datos manuales previos.',
                                        )) {
                                      await _run(() async {
                                        final count = await _repo
                                            .deleteImportBatch(
                                              '${batch['batchId']}',
                                            );
                                        _notice(
                                          '$count registros del lote retirados.',
                                        );
                                      });
                                    }
                                    if (action == 'view') {
                                      await _run(() async {
                                        final history = await _repo
                                            .importHistory(
                                              (batch['id'] as num).toInt(),
                                            );
                                        if (!context.mounted) return;
                                        if (history == null) {
                                          _notice(
                                            'El historial original ya no está disponible.',
                                          );
                                          return;
                                        }
                                        await showDialog<void>(
                                          context: context,
                                          builder: (dialog) => AlertDialog(
                                            title: const Text(
                                              'Historial original local',
                                            ),
                                            content: SizedBox(
                                              width: 600,
                                              child: SingleChildScrollView(
                                                child: SelectableText(
                                                  history.length > 100000
                                                      ? '${history.substring(0, 100000)}\n\nVista limitada a 100000 caracteres. El original completo está guardado localmente.'
                                                      : history,
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dialog),
                                                child: const Text('Cerrar'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }, reload: false);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text('Ver origen'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Retirar este lote'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: !_canEdit ? null : _import,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Importar historial'),
        ),
      ),
    );
  }
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
