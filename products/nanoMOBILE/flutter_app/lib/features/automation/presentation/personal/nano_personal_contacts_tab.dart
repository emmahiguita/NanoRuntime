import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../engine/agent_dependencies.dart'
    show conversationMemoryStoreProvider;
import '../../engine/notifications/notification_object.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../personal_agent/application/persona_context.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/application/personal_contacts_repository.dart';
import '../../personal_agent/domain/personal_contact_policy.dart';
import '../../personal_agent/domain/persona_profile.dart';
import '../../personal_agent/domain/personal_memory.dart'
    show personalizationScope;
import 'nano_personal_contact_dialog.dart';

/// Lista canónica con agrupación múltiple y guardado vinculado a conversaciones.
class NanoPersonalContactsTab extends ConsumerStatefulWidget {
  const NanoPersonalContactsTab({super.key});
  @override
  ConsumerState<NanoPersonalContactsTab> createState() =>
      _NanoPersonalContactsTabState();
}

class _NanoPersonalContactsTabState
    extends ConsumerState<NanoPersonalContactsTab> {
  final _repository = PersonalContactsRepository();
  List<RelationshipProfile> _contacts = [];
  Map<String, String> _conversations = {};
  String? _error;
  String _group = 'Todos';
  bool _busy = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final contacts = await _repository.load();
      final memory = ref.read(conversationMemoryStoreProvider);
      await memory.load();
      final conversations = <String, String>{};
      for (final id in memory.knownConversationIds()) {
        final entries = memory.memoryFor(id)?.entries ?? [];
        final sender = entries
            .where((e) => e.sender.isNotEmpty)
            .lastOrNull
            ?.sender;
        if (sender != null) conversations[id] = sender;
      }
      final active = await NanoRuntimeApi.instance.listNotifications(
        limit: 100,
      );
      for (final row in active) {
        final notification = NotificationObject.fromMap(row);
        final identity = resolveConversationIdentity(notification);
        if (identity.safeToWrite &&
            !notification.isGroup &&
            notification.sender.isNotEmpty) {
          conversations[identity.key.id] = notification.sender;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _contacts = contacts;
        _conversations = conversations;
        _busy = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _error = 'No se pudieron cargar los contactos. Reintenta.';
        });
      }
    }
  }

  Future<void> _edit([RelationshipProfile? existing]) async {
    final result = await showPersonalContactEditor(
      context,
      existing: existing,
      conversations: _conversations,
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (existing != null) {
        await _repository.save(
          existing: existing,
          name: result.name,
          conversationIds: result.conversations,
          groups: result.groups,
          style: result.style,
          autoReply: result.autoReply,
        );
      } else {
        // Cada seleccionado es una persona distinta; las altas repetidas actualizan su ficha.
        for (final id in result.conversations) {
          final stored = _contacts
              .where(
                (p) =>
                    PersonalContactPolicy.conversations(p).contains(id) ||
                    p.relationshipKey == personalizationScope(id),
              )
              .firstOrNull;
          await _repository.save(
            existing: stored,
            name: stored?.displayName ?? _conversations[id]!,
            conversationIds: {
              if (stored != null)
                ...PersonalContactPolicy.conversations(stored),
              id,
            }.toList(),
            groups: {
              ...PersonalContactPolicy.list(stored?.facts['groups']),
              ...result.groups,
            }.toList(),
            style: result.style,
            autoReply: result.autoReply,
          );
        }
      }
      await ref.read(personaContextProvider).refresh();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is StateError
              ? error.message.toString()
              : 'No se pudo guardar el contacto.';
        });
      }
    }
  }

  Future<void> _delete(RelationshipProfile contact) async {
    setState(() => _busy = true);
    try {
      // Borrar una ficha no habilita la automatización de ese chat: conserva una pausa explícita.
      if (!await PersonaRepository.instance.upsertRelationship(
        contact.relationshipKey,
        contact.displayName,
        {...contact.facts, 'autoReply': 'false', 'hiddenFromContacts': 'true'},
      )) {
        throw StateError('No se pudo retirar el contacto.');
      }
      await ref.read(personaContextProvider).refresh();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo retirar el contacto.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _contacts
        .where(
          (p) =>
              p.facts['hiddenFromContacts'] != 'true' &&
              (_group == 'Todos' ||
                  PersonalContactPolicy.list(
                    p.facts['groups'],
                  ).contains(_group)),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (_busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _edit(),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Agregar contactos a grupos'),
            ),
            IconButton(
              tooltip: 'Actualizar contactos',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Una ficha por persona. Familia, amigos y clientes son etiquetas; una persona puede tener varias.',
        ),
        Wrap(
          spacing: 6,
          children: ['Todos', ...PersonalContactPolicy.groups]
              .map(
                (group) => ChoiceChip(
                  label: Text(group),
                  selected: _group == group,
                  onSelected: (_) => setState(() => _group = group),
                ),
              )
              .toList(),
        ),
        if (_error != null) Text(_error!),
        if (!_busy && visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin contactos en este grupo.'),
          ),
        for (final contact in visible)
          Card(
            child: ListTile(
              title: Text(contact.displayName),
              subtitle: Text(
                '${PersonalContactPolicy.list(contact.facts['groups']).join(' · ')}\n'
                '${PersonalContactPolicy.conversations(contact).isEmpty ? 'Sin vincular' : 'Vinculado'} · '
                '${contact.facts['autoReply'] == 'true' ? 'Automático permitido' : 'Solo supervisado'}',
              ),
              onTap: _busy ? null : () => _edit(contact),
              trailing: IconButton(
                tooltip: 'Retirar y pausar',
                onPressed: _busy ? null : () => _delete(contact),
                icon: const Icon(Icons.person_remove_outlined),
              ),
            ),
          ),
      ],
    );
  }
}
