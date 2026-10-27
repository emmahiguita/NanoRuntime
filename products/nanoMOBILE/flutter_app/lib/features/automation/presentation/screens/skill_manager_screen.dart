import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/skills/prompt_skill.dart';
import '../../engine/skills/prompt_skill_importer.dart';
import '../../engine/skills/prompt_skill_provider.dart';
import '../skill_dev_section.dart';

/// Administra instrucciones SKILL.md y las skills de automatización aprobadas.
class SkillManagerScreen extends ConsumerStatefulWidget {
  const SkillManagerScreen({super.key});

  @override
  ConsumerState<SkillManagerScreen> createState() => _SkillManagerScreenState();
}

class _SkillManagerScreenState extends ConsumerState<SkillManagerScreen> {
  List<PromptSkill> _skills = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final store = ref.read(promptSkillStoreProvider);
    await store.load();
    if (mounted) setState(() => _skills = store.all());
  }

  Future<String?> _askFor(String title, String hint, {int lines = 1}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 12,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _install(Future<PromptSkill> Function() loadSkill) async {
    setState(() => _busy = true);
    try {
      final skill = await loadSkill();
      await ref.read(promptSkillStoreProvider).save(skill);
      await _reload();
      if (mounted) _message('Skill “${skill.name}” agregada al chat.');
    } on Object catch (error) {
      if (mounted) {
        _message(
          'No se pudo importar: ${error is FormatException ? error.message : 'revisa la conexión y el archivo'}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Skills de Nano')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Las skills aportan instrucciones al modelo; las herramientas MCP aportan acciones reales. Nano mantiene la gobernanza y pide confirmación para efectos externos. Se importa solo SKILL.md: Nano no ejecuta JavaScript ni scripts de skills.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final url = await _askFor(
                        'Importar desde HTTPS',
                        'URL directa a SKILL.md',
                      );
                      if (url != null && url.trim().isNotEmpty) {
                        await _install(
                          () => const PromptSkillImporter().fromUrl(url),
                        );
                      }
                    },
              icon: const Icon(Icons.link),
              label: const Text('Desde URL'),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final markdown = await _askFor(
                        'Pegar SKILL.md',
                        'Incluye el bloque --- name / description ---',
                        lines: 8,
                      );
                      if (markdown != null && markdown.trim().isNotEmpty) {
                        await _install(
                          () async =>
                              const PromptSkillImporter().fromText(markdown),
                        );
                      }
                    },
              icon: const Icon(Icons.content_paste),
              label: const Text('Pegar skill'),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Skills de instrucciones (${_skills.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_skills.isEmpty)
          const ListTile(title: Text('Aún no has agregado skills.')),
        for (final skill in _skills)
          Card(
            child: ListTile(
              title: Text(skill.name),
              subtitle: Text(
                skill.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Quitar skill',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(promptSkillStoreProvider).remove(skill.name);
                  await _reload();
                },
              ),
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Skills creadas por automatizaciones verificadas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const SkillDevSection(),
      ],
    ),
  );
}
