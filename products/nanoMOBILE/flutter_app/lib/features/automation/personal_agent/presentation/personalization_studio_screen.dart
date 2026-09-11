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
        if (scope.conversationId != null) 'conversationId': scope.conversationId!,
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
        'observedAt': example?.tone['observedAt'] ?? '${DateTime.now().millisecondsSinceEpoch}',
        'ownerVerified': '${result.verified}',
        'kind': result.isTemplate ? 'template' : result.input.isEmpty ? 'style' : 'paired',
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
        await _repo.updateExample(example, body: result.body, incomingText: result.input, tone: tone, scopeKey: result.scope);
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
            'expiresAt': result.expiresAt == null ? '' : '${result.expiresAt!.millisecondsSinceEpoch}',
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
        {'role': 'contact', 'text': 'Hola, ¿cómo vas?', 'timestamp': 1788793200000},
        {'role': 'owner', 'text': 'Bien, gracias. ¿Y tú?', 'timestamp': 1788793201000},
      ],
      'memories': [{'type': 'stablePreference', 'key': 'contacto', 'value': 'Prefiere mensajes breves', 'observedAt': 1788793200000}],
      'templates': [{'incoming': 'Consulta de referencia', 'reply': '¿Cuál referencia buscas?'}],
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

  void _infoDialog(String title, Widget content, {List<Widget>? extraActions}) =>
      showDialog<void>(
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Ayuda',
              onSelected: (action) {
                if (action == 'how') _showHowItLearns();
                if (action == 'formats') _formatHelp();
                if (action == 'privacy') _showPrivacyNote();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'how',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome_outlined),
                    title: Text('¿Cómo aprende Nano?'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'formats',
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Formatos de importación'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'privacy',
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Privacidad de datos'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
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
                      _LearnBanner(onImport: !_canEdit ? null : _import),
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

// ─────────────────────────────────────────────
// Result records (typed, no leakage of widget state)
// ─────────────────────────────────────────────

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
    register = _registers.contains(e['styleRegister']) ? e['styleRegister']! : 'casual';
    relationship = _relationships.contains(e['relationship']) ? e['relationship']! : 'known';
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.scope.id == 'owner' ? 'Mi estilo global' : 'Estilo: ${widget.scope.label}'),
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
                DropdownMenuItem(value: 'casual', child: Text('Casual neutral')),
                DropdownMenuItem(value: 'close', child: Text('Cercano')),
                DropdownMenuItem(value: 'custom', child: Text('Personalizado')),
              ],
              onChanged: (v) => setState(() => register = v!),
            ),
            if (widget.scope.id != 'owner')
              DropdownButtonFormField<String>(
                initialValue: relationship,
                decoration: const InputDecoration(labelText: 'Relación declarada'),
                items: const [
                  DropdownMenuItem(value: 'known', child: Text('Conocido')),
                  DropdownMenuItem(value: 'close', child: Text('Amistad cercana')),
                  DropdownMenuItem(value: 'family', child: Text('Familia')),
                  DropdownMenuItem(value: 'professional', child: Text('Profesional')),
                ],
                onChanged: (v) => setState(() => relationship = v!),
              ),
            DropdownButtonFormField<ToneVerbosity>(
              initialValue: tone.verbosity,
              decoration: const InputDecoration(labelText: 'Longitud'),
              items: [for (final v in ToneVerbosity.values) DropdownMenuItem(value: v, child: Text(v.name))],
              onChanged: (v) => setState(() => tone = tone.copyWith(verbosity: v)),
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
                DropdownMenuItem(value: 'natural', child: Text('Solo cuando sea natural')),
                DropdownMenuItem(value: 'never', child: Text('No usarlo al saludar')),
              ],
              onChanged: (v) => setState(() => usesName = v!),
            ),
            if (widget.scope.id != 'owner')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar este contacto para mi estilo'),
                subtitle: const Text('Permite importar y recuperar sus ejemplos. Desactivarlo no borra datos.'),
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
            const Text('El estilo no acredita ubicación, actividad, stock ni disponibilidad actuales.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () => Navigator.pop(context, _StyleResult(
          register: register, relationship: relationship,
          learn: learn, enabled: enabled, slang: slang,
          usesName: usesName, custom: _custom.text.trim(), tone: tone,
        )),
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
    title: Text(widget.isTemplate ? 'Plantilla de orientación' : 'Ejemplo real del dueño'),
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
              decoration: const InputDecoration(labelText: 'Aplicar solamente a'),
              items: [for (final s in widget.scopes.values) DropdownMenuItem(value: s.id, child: Text(s.label, overflow: TextOverflow.ellipsis))],
              onChanged: widget.busy ? null : (v) { if (v != null) setState(() => scope = v); },
            ),
            TextField(
              controller: _incoming,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Qué me dijeron', helperText: 'Vacío = solo estilo, no par condicionado.'),
            ),
            TextField(
              controller: _reply,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(labelText: widget.isTemplate ? 'Guía de respuesta' : 'Qué respondí realmente'),
            ),
            if (widget.isTemplate)
              const Text('Variables sin datos reales no se rellenan. Una plantilla no prueba stock, precio ni estado actual.'),
            if (!widget.isTemplate)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Esta respuesta la escribí yo; no es una salida de Nano'),
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
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: widget.isTemplate || verified ? () => Navigator.pop(context, _ExampleResult(
          scope: scope, body: _reply.text.trim(), input: _incoming.text.trim(),
          verified: verified, enabled: enabled, isTemplate: widget.isTemplate,
        )) : null,
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
      text: DateTime.fromMillisecondsSinceEpoch(m?.observedAt ?? DateTime.now().millisecondsSinceEpoch).toIso8601String(),
    );
    _expiry = TextEditingController(
      text: m?.expiresAt == null ? '' : DateTime.fromMillisecondsSinceEpoch(m!.expiresAt!).toIso8601String(),
    );
    kind = personalMemoryKinds.containsKey(m?.kind) ? m!.kind : m == null ? 'stablePreference' : 'episodicMemory';
    scope = widget.initialScope;
    enabled = m?.enabled ?? true;
  }

  @override
  void dispose() {
    _key.dispose(); _value.dispose(); _observed.dispose(); _expiry.dispose();
    super.dispose();
  }

  void _submit() {
    final k = _key.text.trim(), v = _value.text.trim();
    final at = DateTime.tryParse(_observed.text);
    final until = _expiry.text.trim().isEmpty ? null : DateTime.tryParse(_expiry.text);
    if (k.isEmpty || v.isEmpty || at == null ||
        (_expiry.text.trim().isNotEmpty && (until == null || !until.isAfter(at))) ||
        (kind == 'temporaryFact' && (until == null || !until.isAfter(at)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completa la clave, valor y fechas válidas. Los datos temporales deben caducar después de observarse.'),
      ));
      return;
    }
    Navigator.pop(context, _MemoryResult(
      scope: scope, key: k, value: v, kind: kind,
      observedAt: at, expiresAt: until, enabled: enabled,
    ));
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
              decoration: const InputDecoration(labelText: 'Aplicar solamente a'),
              items: [for (final s in widget.scopes.values) DropdownMenuItem(value: s.id, child: Text(s.label, overflow: TextOverflow.ellipsis))],
              onChanged: widget.busy ? null : (v) { if (v != null) setState(() => scope = v); },
            ),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Clasificación'),
              items: [for (final entry in personalMemoryKinds.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
              onChanged: (v) => setState(() => kind = v!),
            ),
            TextField(controller: _key, maxLength: 120, decoration: const InputDecoration(labelText: 'Asunto / clave')),
            TextField(controller: _value, maxLength: 2000, maxLines: 4, decoration: const InputDecoration(labelText: 'Dato declarado')),
            TextField(controller: _observed, decoration: const InputDecoration(labelText: 'Fecha de registro / observación (ISO)')),
            TextField(
              controller: _expiry,
              decoration: InputDecoration(labelText: kind == 'temporaryFact' ? 'Caduca (obligatorio, ISO)' : 'Caduca (opcional, ISO)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Memoria activa'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            const Text('Los recuerdos no prueban estado actual. Datos temporales y de negocio quedan para revisión; no sustituyen las fuentes actuales del negocio.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
            label: const Text('Importar historial', style: TextStyle(fontSize: 12)),
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
