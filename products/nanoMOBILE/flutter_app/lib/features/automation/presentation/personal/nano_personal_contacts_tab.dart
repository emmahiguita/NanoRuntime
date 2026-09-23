/// NANO-PERSONAL-CONTACTS-TAB — Pestaña "Personas" de Nano Personal.
///
/// QUÉ HACE:
/// Configuración contextual por contacto (familia, trabajo, amigos),
/// permitiendo definir estilo específico y permiso de respuesta automática.
///
/// CÓMO FUNCIONA:
/// Consulta [PersonaRepository] durable en SQLite (perfiles de relación),
/// permitiendo crear reglas personalizadas por cada contacto clave.
///
/// POR QUÉ:
/// Garantiza que Nano sepa tratar a Mamá de forma cariñosa y cercana,
/// y a un colega de trabajo de manera formal y profesional.
library;

import 'package:flutter/material.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/domain/persona_profile.dart';
import '../automation_visual_theme.dart';
import 'nano_personal_contact_dialog.dart';

class NanoPersonalContactsTab extends StatefulWidget {
  const NanoPersonalContactsTab({super.key});

  @override
  State<NanoPersonalContactsTab> createState() =>
      _NanoPersonalContactsTabState();
}

class _NanoPersonalContactsTabState extends State<NanoPersonalContactsTab> {
  List<PersonaProfile> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await PersonaRepository.instance.listPersonas();
      if (!mounted) return;
      setState(() {
        _contacts = list.where((p) => p.personaKey != 'owner').toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEditContact([PersonaProfile? existing]) async {
    final result = await NanoPersonalContactDialog.show(context, existing);
    if (result != null) {
      final key = existing?.personaKey ??
          'contact_${DateTime.now().millisecondsSinceEpoch}';
      await PersonaRepository.instance.upsertPersona(key, result.name, {
        'relationship': result.relationship,
        'styleRegister': result.styleRegister,
        'autoReply': result.autoReply ? 'true' : 'false',
      });
      await _loadContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visual = AutomationVisual.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        FilledButton.icon(
          onPressed: () => _addOrEditContact(),
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Agregar trato por contacto'),
          style: FilledButton.styleFrom(
            backgroundColor: visual.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Sin contactos configurados.\nAgrega personas clave para darles un trato especial.',
                textAlign: TextAlign.center,
                style: TextStyle(color: visual.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ..._contacts.map((c) => _buildContactCard(visual, c)),
      ],
    );
  }

  Widget _buildContactCard(AutomationVisualPalette visual, PersonaProfile c) {
    final relation = c.facts['relationship'] ?? 'General';
    final style = c.facts['styleRegister'] ?? 'Cercano';
    final autoReply = c.facts['autoReply'] != 'false';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: visual.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: visual.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: visual.accent.withValues(alpha: 0.2),
            child: Text(
              c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
              style: TextStyle(color: visual.accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.displayName,
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$relation · Estilo $style · ${autoReply ? 'Auto' : 'Supervisado'}',
                  style: TextStyle(color: visual.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: visual.textMuted,
            onPressed: () => _addOrEditContact(c),
          ),
        ],
      ),
    );
  }
}
