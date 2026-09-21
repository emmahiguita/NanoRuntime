import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/bot/bot_agent_dispatcher.dart';
import 'bot_repository.dart';

/// QUÉ HACE:
/// Provee la instancia global del repositorio de bots.
final botRepositoryProvider = Provider<BotRepository>((ref) {
  return BotRepository.instance;
});

/// QUÉ HACE:
/// ID del bot activo para inspección o edición en Bot Studio.
final activeBotIdProvider = StateProvider<String?>((ref) => null);

/// QUÉ HACE:
/// Notifier reactivo que expone la lista de bots y permite mutaciones durables.
///
/// CÓMO FUNCIONA:
/// Carga inicialmente los bots desde SQLite / SharedPreferences a través de
/// [BotRepository] y actualiza el estado inmutable en memoria ante cada cambio.
///
/// POR QUÉ:
/// Desacopla la interfaz visual de la persistencia de datos (Clean Architecture).
class BotsListNotifier extends AsyncNotifier<List<BotDefinition>> {
  @override
  Future<List<BotDefinition>> build() async {
    final repo = ref.watch(botRepositoryProvider);
    return await repo.listBots();
  }

  /// Guarda o actualiza un bot de forma duradera.
  Future<void> saveBot(BotDefinition bot) async {
    final repo = ref.read(botRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.upsertBot(bot);
      return await repo.listBots();
    });
  }

  /// Elimina un bot por su ID.
  Future<void> deleteBot(String id) async {
    final repo = ref.read(botRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.deleteBot(id);
      return await repo.listBots();
    });
  }

  /// Alterna una habilidad específica para un bot existente.
  Future<void> toggleSkill(String botId, String skillId) async {
    final currentList = state.valueOrNull ?? [];
    final target = currentList.where((b) => b.id == botId).firstOrNull;
    if (target == null) return;

    final updatedSkills = List<String>.from(target.skillIds);
    if (updatedSkills.contains(skillId)) {
      updatedSkills.remove(skillId);
    } else {
      updatedSkills.add(skillId);
    }

    final updatedBot = target.copyWith(
      skillIds: updatedSkills,
      updatedAt: DateTime.now(),
    );

    await saveBot(updatedBot);
  }

  /// Crea un nuevo bot con valores predeterminados según su rol.
  Future<BotDefinition> createNewBot({
    required String name,
    required BotRole role,
    String description = '',
  }) async {
    final now = DateTime.now();
    final newBot = BotDefinition(
      id: "bot_${now.millisecondsSinceEpoch}",
      name: name,
      role: role,
      description: description,
      goal: role.defaultGoal,
      skillIds: role == BotRole.personal
          ? ['skill_linux', 'skill_browser', 'skill_whatsapp', 'skill_memory']
          : ['skill_whatsapp', 'skill_catalog'],
      createdAt: now,
      updatedAt: now,
    );

    await saveBot(newBot);
    return newBot;
  }
}

/// Provider global reactivo de la lista de bots.
final botsListProvider =
    AsyncNotifierProvider<BotsListNotifier, List<BotDefinition>>(
  BotsListNotifier.new,
);

/// Provider derivado que obtiene el bot actualmente seleccionado o el personal por defecto.
final activeBotProvider = Provider<BotDefinition?>((ref) {
  final botsAsync = ref.watch(botsListProvider);
  final activeId = ref.watch(activeBotIdProvider);

  return botsAsync.when(
    data: (bots) {
      if (bots.isEmpty) return null;
      if (activeId != null) {
        final found = bots.where((b) => b.id == activeId).firstOrNull;
        if (found != null) return found;
      }
      // Por defecto el bot del dueño (personal) o el primero
      return bots.where((b) => b.role == BotRole.personal).firstOrNull ??
          bots.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// QUÉ HACE:
/// Provee el despachador de bots con las herramientas reales del agente.
final botAgentDispatcherProvider = Provider<BotAgentDispatcher>((ref) {
  final dispatcher = ref.watch(agentDispatcherProvider);
  return BotAgentDispatcher(toolDispatcher: dispatcher);
});
