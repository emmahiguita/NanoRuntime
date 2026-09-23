/// NANO-PERSONAL-MEMORY-TAB — Pestaña "Memoria" de Nano Personal.
///
/// QUÉ HACE:
/// Muestra y gestiona los datos que Nano conoce sobre el usuario
/// (preferencias, actividades, rutinas, lugares) para responder con la verdad.
///
/// CÓMO FUNCIONA:
/// Lee y escribe directamente en [PersonaRepository] durable en SQLite
/// (tabla de memorias personales), permitiendo añadir, editar y eliminar hechos.
///
/// POR QUÉ:
/// Separa claramente "cómo hablo" de "qué sabe Nano sobre mí",
/// otorgando control y transparencia total al usuario sobre sus datos.
library;

import 'package:flutter/material.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/domain/personal_memory.dart';
import '../automation_visual_theme.dart';
import 'nano_personal_memory_dialog.dart';

class NanoPersonalMemoryTab extends StatefulWidget {
  const NanoPersonalMemoryTab({super.key});

  @override
  State<NanoPersonalMemoryTab> createState() => _NanoPersonalMemoryTabState();
}

class _NanoPersonalMemoryTabState extends State<NanoPersonalMemoryTab> {
  List<PersonalMemory> _memories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      final list = await PersonaRepository.instance.listPersonalMemories(scopeKey: 'owner');
      if (!mounted) return;
      setState(() {
        _memories = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEditMemory([PersonalMemory? existing]) async {
    final memory = await NanoPersonalMemoryDialog.show(context, existing);
    if (memory != null) {
      await PersonaRepository.instance.savePersonalMemory(memory);
      await _loadMemories();
    }
  }

  Future<void> _deleteMemory(PersonalMemory memory) async {
    await PersonaRepository.instance.deletePersonalMemory(memory.id);
    await _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visual = AutomationVisual.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visual.surface.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: visual.outline.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Icon(Icons.psychology_outlined, size: 20, color: visual.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Datos reales sobre ti para responder con la verdad y nunca inventar hechos.',
                  style: TextStyle(color: visual.text, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _addOrEditMemory(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agregar nuevo dato sobre mí'),
          style: FilledButton.styleFrom(
            backgroundColor: visual.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_memories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Sin datos registrados todavía.\nAgrega información que Nano deba recordar sobre ti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: visual.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ..._memories.map((m) => _buildMemoryCard(visual, m)),
      ],
    );
  }

  Widget _buildMemoryCard(AutomationVisualPalette visual, PersonalMemory m) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.key,
                  style: TextStyle(
                    color: visual.accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.value,
                  style: TextStyle(color: visual.text, fontSize: 13.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: visual.textMuted,
            onPressed: () => _deleteMemory(m),
          ),
        ],
      ),
    );
  }
}
