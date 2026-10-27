import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart';
import '../../application/bot/bot_studio_providers.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import 'bot_card.dart';
import 'bot_editor_dialog.dart';

/// Pantalla principal de Bot Studio estilo iOS compacto y profesional.
class BotStudioScreen extends ConsumerStatefulWidget {
  const BotStudioScreen({super.key});

  @override
  ConsumerState<BotStudioScreen> createState() => _BotStudioScreenState();
}

class _BotStudioScreenState extends ConsumerState<BotStudioScreen> {
  BotRole? _filterRole;

  void _onCreateBot() async {
    final now = DateTime.now();
    final template = BotDefinition(
      id: "bot_${now.millisecondsSinceEpoch}",
      name: "Nuevo Asistente",
      role: BotRole.assistant,
      createdAt: now,
      updatedAt: now,
    );

    final created = await BotEditorDialog.show(context, template);
    if (created != null) {
      ref.read(botsListProvider.notifier).saveBot(created);
    }
  }

  void _onEditBot(BotDefinition bot) async {
    final updated = await BotEditorDialog.show(context, bot);
    if (updated != null) {
      ref.read(botsListProvider.notifier).saveBot(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final botsAsync = ref.watch(botsListProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: NanoShellBarScope(
        slotId: 'bot_studio',
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, kNanoBarScrollReserve),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AutomationLayout.contentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AutomationBackHeader(),
                      const SizedBox(height: 8),
                      _buildHeader(visual),
                      const SizedBox(height: 12),
                      _buildRoleFilters(visual),
                      const SizedBox(height: 12),
                      botsAsync.when(
                        data: (bots) {
                          final filtered = _filterRole == null
                              ? bots
                              : bots.where((b) => b.role == _filterRole).toList();

                          if (filtered.isEmpty) {
                            return _buildEmptyState(visual);
                          }

                          return Column(
                            children: filtered
                                .map(
                                  (bot) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: BotCard(
                                      bot: bot,
                                      onEdit: () => _onEditBot(bot),
                                      onToggleEnabled: (val) {
                                        final updated = bot.copyWith(
                                          enabled: val,
                                          updatedAt: DateTime.now(),
                                        );
                                        ref
                                            .read(botsListProvider.notifier)
                                            .saveBot(updated);
                                      },
                                      onDelete: () {
                                        ref
                                            .read(botsListProvider.notifier)
                                            .deleteBot(bot.id);
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                        error: (err, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: $err',
                              style: TextStyle(color: visual.textMuted, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nuevo Bot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        backgroundColor: visual.accent,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _onCreateBot,
      ),
    );
  }

  Widget _buildHeader(AutomationVisualPalette visual) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                visual.accent.withValues(alpha: 0.25),
                visual.accent.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: visual.accent.withValues(alpha: 0.40),
              width: 0.8,
            ),
          ),
          child: Icon(Icons.smart_toy_rounded, color: visual.accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bot Studio',
                style: TextStyle(
                  color: visual.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Crea y especializa agentes con herramientas reales',
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 11.5,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleFilters(AutomationVisualPalette visual) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterPill(
            label: 'Todos',
            isSelected: _filterRole == null,
            visual: visual,
            onTap: () => setState(() => _filterRole = null),
          ),
          const SizedBox(width: 6),
          ...BotRole.values.map((role) {
            final isSelected = _filterRole == role;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildFilterPill(
                label: role.label,
                isSelected: isSelected,
                visual: visual,
                onTap: () => setState(() => _filterRole = role),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required AutomationVisualPalette visual,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? visual.accent
              : visual.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? visual.accent
                : (visual.isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06)),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : visual.text,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AutomationVisualPalette visual) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 36,
              color: visual.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay bots para este filtro',
              style: TextStyle(
                color: visual.textMuted,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
