import 'package:flutter/material.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import '../../engine/messaging/tone_profile.dart';
import 'bot_skills_selector.dart';

/// QUÉ HACE:
/// Modal interactivo para crear o editar la configuración completa de un bot.
///
/// CÓMO FUNCIONA:
/// Permite modificar el nombre, rol, descripción, tono conversacional y
/// habilidades asignadas, devolviendo el [BotDefinition] actualizado al guardar.
///
/// POR QUÉ:
/// Ofrece un punto central de gobernanza para cada bot en Bot Studio.
class BotEditorDialog extends StatefulWidget {
  final BotDefinition bot;

  const BotEditorDialog({super.key, required this.bot});

  static Future<BotDefinition?> show(BuildContext context, BotDefinition bot) {
    return showModalBottomSheet<BotDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      tone: widget.bot.tone.copyWith(
        warmth: _warmth,
        verbosity: _verbosity,
      ),
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
        left: 20,
        right: 20,
        top: 20,
        bottom: insets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.bot.id.startsWith("bot_") ? 'Editar Bot' : 'Configurar Bot',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Bot',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción / Propósito',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text('Rol de Operación', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<BotRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: BotRole.values.map((r) {
                return DropdownMenuItem(value: r, child: Text(r.label));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 16),
            Text('Calidez del Tono', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ToneWarmth>(
              segments: const [
                ButtonSegment(value: ToneWarmth.cercano, label: Text('Cercano')),
                ButtonSegment(value: ToneWarmth.formal, label: Text('Formal')),
              ],
              selected: {_warmth},
              onSelectionChanged: (set) => setState(() => _warmth = set.first),
            ),
            const SizedBox(height: 16),
            Text('Habilidades Activas (Skills)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            BotSkillsSelector(
              selectedSkillIds: _skillIds,
              onChanged: (skills) => setState(() => _skillIds = skills),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar Cambios'),
                onPressed: _onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
