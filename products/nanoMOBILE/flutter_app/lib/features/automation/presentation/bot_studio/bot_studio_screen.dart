import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bot/bot_studio_providers.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import 'bot_card.dart';
import 'bot_editor_dialog.dart';

/// QUÉ HACE:
/// Pantalla principal de Bot Studio para gestionar todos los agentes de NanoAI.
///
/// CÓMO FUNCIONA:
/// Observa [botsListProvider], muestra la lista reactiva de bots, permite filtrarlos
/// por rol y provee diálogos para crear y editar configuraciones.
///
/// POR QUÉ:
/// Centraliza la administración de bots en una interfaz moderna y coherente.
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
    final theme = Theme.of(context);
    final botsAsync = ref.watch(botsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Studio'),
        centerTitle: false,
        actions: [
          Semantics(
            label: 'Crear nuevo bot',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _onCreateBot,
            ),
          ),
        ],
      ),
      body: botsAsync.when(
        data: (bots) {
          final filtered = _filterRole == null
              ? bots
              : bots.where((b) => b.role == _filterRole).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildRoleFilters(theme),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _buildEmptyState(theme)
              else
                ...filtered.map((bot) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BotCard(
                        bot: bot,
                        onEdit: () => _onEditBot(bot),
                        onToggleEnabled: (val) {
                          final updated = bot.copyWith(
                            enabled: val,
                            updatedAt: DateTime.now(),
                          );
                          ref.read(botsListProvider.notifier).saveBot(updated);
                        },
                        onDelete: () {
                          ref.read(botsListProvider.notifier).deleteBot(bot.id);
                        },
                      ),
                    )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar bots: $err'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Bot'),
        onPressed: _onCreateBot,
      ),
    );
  }

  Widget _buildRoleFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            selected: _filterRole == null,
            label: const Text('Todos'),
            onSelected: (_) => setState(() => _filterRole = null),
          ),
          const SizedBox(width: 8),
          ...BotRole.values.map((role) {
            final isSelected = _filterRole == role;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(role.label),
                onSelected: (_) => setState(() => _filterRole = role),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No hay bots para este filtro',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
