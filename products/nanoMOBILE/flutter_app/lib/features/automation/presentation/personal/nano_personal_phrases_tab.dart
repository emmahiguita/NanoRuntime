/// NANO-PERSONAL-PHRASE-TAB — Pestaña organizada de Frases y Diálogos con filtros de temas.
library;

import 'package:flutter/material.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/domain/persona_example.dart';
import '../automation_visual_theme.dart';
import 'nano_personal_example_card.dart';
import 'nano_personal_phrase_dialog.dart';

part 'nano_personal_phrase_actions.part.dart';

class NanoPersonalPhrasesTab extends StatefulWidget {
  const NanoPersonalPhrasesTab({super.key});

  @override
  State<NanoPersonalPhrasesTab> createState() => _NanoPersonalPhrasesTabState();
}

class _NanoPersonalPhrasesTabState extends State<NanoPersonalPhrasesTab> {
  static const _filterTags = [
    'Todas',
    'Saludos',
    'Cotidiano',
    'Reencuentro',
    'Disponibilidad',
    'Planes',
    'Opinión',
    'Despedidas',
    'Cierre',
  ];
  String _activeTag = 'Todas';
  List<PersonaExample> _examples = [];
  bool _loading = true, _writing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExamples();
  }

  List<PersonaExample> get _filteredExamples {
    if (_activeTag == 'Todas') return _examples;
    final term = _activeTag.toLowerCase();
    return _examples
        .where(
          (e) =>
              e.category.toLowerCase().contains(term) ||
              e.intent.toLowerCase().contains(term),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visual = AutomationVisual.of(context);
    final displayed = _filteredExamples;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (_writing) const LinearProgressIndicator(),
        if (_error != null) TextButton(onPressed: _loadExamples, child: Text('$_error Reintentar')),
        // Selector horizontal de Temas / Categorías
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterTags.map((t) {
              final isSel = _activeTag == t;
              final count = t == 'Todas'
                  ? _examples.length
                  : _examples
                        .where(
                          (e) => e.category.toLowerCase().contains(
                            t.toLowerCase(),
                          ),
                        )
                        .length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    '$t ($count)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
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
          onPressed: _writing ? null : () => _addOrEditPhrase(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agregar diálogo e intención'),
          style: FilledButton.styleFrom(
            backgroundColor: visual.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No hay diálogos en esta categoría.\nToca "Agregar diálogo" para crear uno.',
                textAlign: TextAlign.center,
                style: TextStyle(color: visual.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...displayed.map(
            (ex) => NanoPersonalExampleCard(
              example: ex,
              onToggleEnabled: _writing ? null : (v) => _toggleEnabled(ex, v),
              onEdit: _writing ? null : () => _addOrEditPhrase(ex),
              onAddResponse: _writing ? null : () => _addResponseQuickly(ex),
              onDelete: _writing ? null : () => _deletePhrase(ex),
            ),
          ),
      ],
    );
  }
}
