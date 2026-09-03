import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_section_card.dart';

import '../engine/agent_dependencies.dart';
import '../engine/skills/skill.dart';
import '../engine/skills/verified_skill.dart';

/// SKILL-UI — superficie Dev de skills (SKILL-01).
///
/// Un draft NO es ejecutable: esta sección es el único punto donde el usuario
/// aprueba (hecho humano) o rechaza una skill extraída de una traza
/// verificada. Las aprobaciones son durables hasta revocarlas aquí mismo.
/// Nada de esto ejecuta la skill: solo cambia su estado en el store.
class SkillDevSection extends ConsumerStatefulWidget {
  const SkillDevSection({super.key});

  @override
  ConsumerState<SkillDevSection> createState() => _SkillDevSectionState();
}

class _SkillDevSectionState extends ConsumerState<SkillDevSection> {
  List<Skill> _drafts = const [];
  List<VerifiedSkill> _approved = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// La hidratación del store es asíncrona: esperar load() antes de leer
  /// evita mostrar "Sin drafts" por raza en el primer build (mismo patrón
  /// que el espejo de conversación).
  Future<void> _refresh() async {
    final store = ref.read(skillStoreProvider);
    await store.load();
    if (!mounted) return;
    setState(() {
      _drafts = store.allDrafts();
      _approved = store.approved();
    });
  }

  Future<void> _approve(String skillId) async {
    await ref.read(skillStoreProvider).approve(skillId);
    _refresh();
  }

  Future<void> _reject(String skillId) async {
    await ref.read(skillStoreProvider).reject(skillId);
    _refresh();
  }

  Future<void> _revoke(String skillId) async {
    await ref.read(skillStoreProvider).revoke(skillId);
    _refresh();
  }

  static String _hhmm(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NanoSectionCard(
          title: 'Skills · drafts (SKILL-01)',
          child: _drafts.isEmpty
              ? Text(
                  'Sin drafts. Una traza verificada del journal genera uno.',
                  style: NanoType.caption(colors.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final skill in _drafts) ...[
                      _draftTile(skill),
                      if (skill != _drafts.last)
                        const Divider(height: NanoSpacing.md),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: NanoSpacing.lg),
        NanoSectionCard(
          title: 'Skills · aprobadas por ti',
          child: _approved.isEmpty
              ? Text(
                  'Ninguna. La aprobación es explícita: una skill aprobada '
                  'puede ejecutarse bajo el MISMO Policy → Journal → '
                  'CommitGuard que todo lo demás.',
                  style: NanoType.caption(colors.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final verified in _approved) ...[
                      _approvedTile(verified),
                      if (verified != _approved.last)
                        const Divider(height: NanoSpacing.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _draftTile(Skill skill) {
    final colors = NanoThemeExtension.of(context).colors;
    final post = skill.expectedPostconditions.map((c) => c.name).join(' · ');
    final steps = skill.steps
        .map(
          (s) => s.inputs.isEmpty
              ? s.semanticAction
              : '${s.semanticAction}(${s.inputs.join(', ')})',
        )
        .join(' → ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${skill.id} · extraída ${_hhmm(skill.extractedAt)}',
          style: NanoType.body(colors.onSurface),
        ),
        const SizedBox(height: NanoSpacing.xs),
        Text(
          steps,
          style: NanoType.caption(colors.onSurfaceVariant),
        ),
        if (post.isNotEmpty) ...[
          const SizedBox(height: NanoSpacing.xs),
          Text(
            'post: $post',
            style: NanoType.caption(colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: NanoSpacing.xs),
        Text(
          'origen ${skill.sourceRunId.length > 24 ? '${skill.sourceRunId.substring(0, 24)}…' : skill.sourceRunId}',
          // outline claro (#A8B4C2 ≈ 2.2:1 sobre blanco) es ilegible en
          // caption: usar el secundario legible.
          style: NanoType.caption(colors.onSurfaceVariant),
        ),
        const SizedBox(height: NanoSpacing.xs),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _approve(skill.id),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Aprobar'),
            ),
            const SizedBox(width: NanoSpacing.sm),
            TextButton.icon(
              onPressed: () => _reject(skill.id),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Rechazar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _approvedTile(VerifiedSkill verified) {
    final colors = NanoThemeExtension.of(context).colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '${verified.skill.id} · aprobada ${_hhmm(verified.approvedAt)}',
            style: NanoType.body(colors.onSurface),
          ),
        ),
        TextButton.icon(
          onPressed: () => _revoke(verified.skill.id),
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Revocar'),
        ),
      ],
    );
  }
}
