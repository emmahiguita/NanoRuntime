/// Lista contactos y permite seleccionar uno, varios o todos para asignar agente.
/// La selección se limita a la lista filtrada que ya entrega Nano.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/whatsapp_contact.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../widgets/conversation_detail_sheet.dart';
import 'whatsapp_contact_card.dart';

/// Mantiene selección efímera; solo persiste asignaciones al pulsar el botón.
class MessagingContactSelectionList extends ConsumerStatefulWidget {
  const MessagingContactSelectionList({super.key, required this.contacts});

  final List<WhatsAppContact> contacts;

  @override
  ConsumerState<MessagingContactSelectionList> createState() =>
      _MessagingContactSelectionListState();
}

class _MessagingContactSelectionListState
    extends ConsumerState<MessagingContactSelectionList> {
  final Set<String> _selected = {};
  ConversationAgentId _agent = ConversationAgentId.personal;
  bool _selecting = false;
  bool _saving = false;

  // La llave estable del contacto mantiene la selección aunque cambie el filtro.
  void _toggleContact(WhatsAppContact contact) {
    setState(() {
      if (!_selected.add(contact.jid)) _selected.remove(contact.jid);
    });
  }

  // Asigna en orden para respetar la cola durable del almacenamiento SQLite.
  Future<void> _assignAgent() async {
    final targets = widget.contacts
        .where((contact) => _selected.contains(contact.jid))
        .toList(growable: false);
    if (targets.isEmpty || _saving) return;
    setState(() => _saving = true);
    var assigned = 0;
    try {
      final store = ref.read(conversationAssignmentStoreProvider);
      for (final contact in targets) {
        await store.transfer(
          contact.jid,
          _agent,
          reason: 'messaging-center-selection',
        );
        assigned++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agente ${_agent.displayName} asignado a $assigned contactos.',
          ),
        ),
      );
      setState(() {
        _selected.clear();
        _selecting = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asignados $assigned de ${targets.length}; error: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // El mismo item real abre el detalle existente cuando no está activo seleccionar.
  void _openConversation(WhatsAppContact contact) {
    ConversationDetailSheet.show(
      context,
      ConversationSummaryItem(
        conversationId: contact.jid,
        displayName: contact.name,
        packageName: contact.isBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp',
        lastMessage: contact.number.isNotEmpty ? contact.number : contact.jid,
        lastAtMs: DateTime.now().millisecondsSinceEpoch,
        agentId: contact.isBusiness
            ? ConversationAgentId.business
            : ConversationAgentId.personal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      // Los controles comparten el scroll sin forzar a medir todas las filas.
      SliverToBoxAdapter(child: _buildSelectionControls()),
      SliverList.builder(
        itemCount: widget.contacts.length,
        itemBuilder: (context, index) => _buildContact(widget.contacts[index]),
      ),
    ],
  );

  // Estas acciones operan sobre contactos visibles; no envían mensajes.
  Widget _buildSelectionControls() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving
                ? null
                : () => setState(() {
                    _selecting = !_selecting;
                    _selected.clear();
                  }),
            icon: Icon(
              _selecting ? Icons.close_rounded : Icons.checklist_rounded,
            ),
            label: Text(
              _selecting ? 'Cancelar selección' : 'Seleccionar contactos',
            ),
          ),
        ),
        if (_selecting) ...[
          Row(
            children: [
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        if (_selected.length == widget.contacts.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(
                              widget.contacts.map((contact) => contact.jid),
                            );
                        }
                      }),
                child: Text(
                  _selected.length == widget.contacts.length
                      ? 'Quitar todos'
                      : 'Seleccionar todos',
                ),
              ),
              const Spacer(),
              Text('${_selected.length} seleccionados'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ConversationAgentId>(
                  initialValue: _agent,
                  decoration: const InputDecoration(
                    labelText: 'Asignar agente',
                  ),
                  items: ConversationAgentId.values
                      .map(
                        (agent) => DropdownMenuItem(
                          value: agent,
                          child: Text(agent.displayName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (agent) => setState(() => _agent = agent ?? _agent),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _assignAgent,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Asignar'),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  // El checkbox aparece solo en selección; tocar la tarjeta sigue abriendo el chat.
  Widget _buildContact(WhatsAppContact contact) {
    final selected = _selected.contains(contact.jid);
    return Row(
      children: [
        Expanded(
          child: WhatsAppContactCard(
            contact: contact,
            onTap: _selecting
                ? () => _toggleContact(contact)
                : () => _openConversation(contact),
          ),
        ),
        if (_selecting)
          Checkbox(
            value: selected,
            onChanged: _saving ? null : (_) => _toggleContact(contact),
          ),
      ],
    );
  }
}
