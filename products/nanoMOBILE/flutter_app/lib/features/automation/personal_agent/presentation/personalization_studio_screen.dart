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

part 'personalization_studio_actions.dart';
part 'personalization_studio_dialogs.dart';

class PersonalizationStudioScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const PersonalizationStudioScreen({super.key, this.initialIndex = 0});
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

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

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
      initialIndex: widget.initialIndex,
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
                          FilledButton.tonalIcon(
                            onPressed: !_canEdit ? null : () => _editExample(),
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Agregar diálogo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: !_canEdit
                                ? null
                                : () => _editExample(template: true),
                            icon: const Icon(Icons.view_quilt_outlined),
                            label: const Text('Agregar plantilla'),
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
