import 'package:flutter/material.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import '../../engine/messaging/tone_profile.dart';
import 'bot_skills_selector.dart';

/// Modal interactivo compacto estilo iOS para configurar agentes.
class BotEditorDialog extends StatefulWidget {
  final BotDefinition bot;

  const BotEditorDialog({super.key, required this.bot});

  static Future<BotDefinition?> show(BuildContext context, BotDefinition bot) {
    return showModalBottomSheet<BotDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => BotEditorDialog(bot: bot),
    );
  }

  @override
  State<BotEditorDialog> createState() => _BotEditorDialogState();
}

class _BotEditorDialogState extends State<BotEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late BotRole _selectedRole;
  late ToneWarmth _warmth;
  late ToneVerbosity _verbosity;
  late List<String> _skillIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bot.name);
    _descController = TextEditingController(text: widget.bot.description);
    _selectedRole = widget.bot.role;
    _warmth = widget.bot.tone.warmth;
    _verbosity = widget.bot.tone.verbosity;
    _skillIds = List.from(widget.bot.skillIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updated = widget.bot.copyWith(
      name: name,
      role: _selectedRole,
      description: _descController.text.trim(),
      tone: widget.bot.tone.copyWith(warmth: _warmth, verbosity: _verbosity),
      skillIds: _skillIds,
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: insets.bottom + 14,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.bot.id.startsWith("bot_") ? 'Editar Agente' : 'Configurar Agente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Nombre del Bot',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                labelText: 'Descripción / Propósito',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text('Rol de Operación', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            DropdownButtonFormField<BotRole>(
              initialValue: _selectedRole,
              isDense: true,
              style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              items: BotRole.values.map((r) {
                return DropdownMenuItem(value: r, child: Text(r.label, style: const TextStyle(fontSize: 12.5)));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 12),
            Text('Calidez del Tono', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: SegmentedButton<ToneWarmth>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                segments: const [
                  ButtonSegment(value: ToneWarmth.cercano, label: Text('Cercano')),
                  ButtonSegment(value: ToneWarmth.formal, label: Text('Formal')),
                ],
                selected: {_warmth},
                onSelectionChanged: (set) => setState(() => _warmth = set.first),
              ),
            ),
            const SizedBox(height: 12),
            Text('Habilidades Activas (Skills)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            BotSkillsSelector(
              selectedSkillIds: _skillIds,
              onChanged: (skills) => setState(() => _skillIds = skills),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Guardar Configuración', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
