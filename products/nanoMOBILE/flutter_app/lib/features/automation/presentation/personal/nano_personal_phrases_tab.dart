/// NANO-PERSONAL-PHRASE-TAB — Pestaña organizada de Frases y Diálogos con filtros de temas.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/domain/persona_example.dart';
import '../automation_visual_theme.dart';
import 'nano_personal_example_card.dart';
import 'nano_personal_phrase_dialog.dart';

class NanoPersonalPhrasesTab extends StatefulWidget {
  const NanoPersonalPhrasesTab({super.key});

  @override
  State<NanoPersonalPhrasesTab> createState() => _NanoPersonalPhrasesTabState();
}

class _NanoPersonalPhrasesTabState extends State<NanoPersonalPhrasesTab> {
  static const _filterTags = ['Todas', 'Saludos', 'Cotidiano', 'Reencuentro', 'Opinión', 'Despedidas'];
  String _activeTag = 'Todas';
  List<PersonaExample> _examples = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExamples();
  }

  Future<void> _loadExamples() async {
    try {
      final list = await PersonaRepository.instance.listExamples(scopeKey: 'owner');
      if (!mounted) return;
      setState(() { _examples = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleEnabled(PersonaExample ex, bool val) async {
    final tone = {...ex.tone, 'enabled': val ? 'true' : 'false'};
    await PersonaRepository.instance.updateExample(ex, tone: tone);
    await _loadExamples();
  }

  Future<void> _addOrEditPhrase([PersonaExample? existing]) async {
    final ex = await NanoPersonalPhraseDialog.show(context, existing);
    if (ex == null) return;
    if (existing != null) {
      await PersonaRepository.instance.updateExample(existing, incomingText: ex.incomingText, body: ex.body, tone: ex.tone);
    } else {
      await PersonaRepository.instance.addExample(personaKey: 'owner', incomingText: ex.incomingText, body: ex.body, tone: ex.tone, source: 'manual');
    }
    await _loadExamples();
  }

  Future<void> _addResponseQuickly(PersonaExample ex) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: Text('Nueva respuesta a "${ex.displayTrigger}"', style: const TextStyle(fontSize: 13.5, color: Colors.white)),
        content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(hintText: 'Cómo responderías tú...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final currentOpts = [...ex.responseOptions, PersonaResponseOption(text: ctrl.text.trim())];
      final tone = {...ex.tone, 'variants': jsonEncode(currentOpts.map((r) => r.text).toList()), 'responses': jsonEncode(currentOpts.map((r) => r.toMap()).toList())};
      await PersonaRepository.instance.updateExample(ex, tone: tone);
      await _loadExamples();
    }
    ctrl.dispose();
  }

  Future<void> _deletePhrase(PersonaExample ex) async {
    await PersonaRepository.instance.deleteExample(ex.id);
    await _loadExamples();
  }

  List<PersonaExample> get _filteredExamples {
    if (_activeTag == 'Todas') return _examples;
    final term = _activeTag.toLowerCase();
    return _examples.where((e) => e.category.toLowerCase().contains(term) || e.intent.toLowerCase().contains(term)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visual = AutomationVisual.of(context);
    final displayed = _filteredExamples;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Selector horizontal de Temas / Categorías
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterTags.map((t) {
              final isSel = _activeTag == t;
              final count = t == 'Todas' ? _examples.length : _examples.where((e) => e.category.toLowerCase().contains(t.toLowerCase())).length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('$t ($count)', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.w500)),
                  selected: isSel,
                  selectedColor: visual.accent.withValues(alpha: 0.22),
                  checkmarkColor: visual.accent,
                  onSelected: (_) => setState(() => _activeTag = t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => _addOrEditPhrase(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agregar diálogo e intención'),
          style: FilledButton.styleFrom(
            backgroundColor: visual.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        if (displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No hay diálogos en esta categoría.\nToca "Agregar diálogo" para crear uno.', textAlign: TextAlign.center, style: TextStyle(color: visual.textMuted, fontSize: 13)),
            ),
          )
        else
          ...displayed.map((ex) => NanoPersonalExampleCard(
                example: ex,
                onToggleEnabled: (v) => _toggleEnabled(ex, v),
                onEdit: () => _addOrEditPhrase(ex),
                onAddResponse: () => _addResponseQuickly(ex),
                onDelete: () => _deletePhrase(ex),
              )),
      ],
    );
  }
}
