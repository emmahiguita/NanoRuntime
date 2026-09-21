/// BOT-REPOSITORY-01 — Persistencia Durable y Gestión CRUD de Bots en NanoAI.
///
/// **QUÉ HACE:**
/// Administra el ciclo de vida de los bots configurados (lectura, escritura, borrado)
/// y provee semillas iniciales para asistentes personales, comerciales y de soporte.
///
/// **CÓMO FUNCIONA:**
/// Almacena las definiciones completas en SharedPreferences local con sincronización
/// en memoria rápida, exponiendo métodos reactivos para Riverpod y el Bot Runtime.
///
/// **POR QUÉ:**
/// Garantiza que la identidad, habilidades y reglas de cada bot permanezcan intactas
/// entre reinicios de la aplicación o del dispositivo sin depender de servidores externos.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_permissions.dart';
import '../../domain/bot/bot_role.dart';
import 'bot_skills_catalog.dart';

class BotRepository {
  static const _storageKey = 'nano_bots_registry_v1';
  static final BotRepository instance = BotRepository._();
  BotRepository._();

  final Map<String, BotDefinition> _cache = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map) {
            final bot = BotDefinition.fromMap(item);
            _cache[bot.id] = bot;
          }
        }
      }
      if (_cache.isEmpty) {
        await _seedDefaultBots();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[BotRepository] Error cargando bots: $e');
      if (_cache.isEmpty) await _seedDefaultBots();
      _initialized = true;
    }
  }

  Future<List<BotDefinition>> listBots() async {
    await init();
    return _cache.values.toList();
  }

  Future<BotDefinition?> getBot(String id) async {
    await init();
    return _cache[id];
  }

  Future<BotDefinition?> getActiveBotForChannel(String channel) async {
    await init();
    for (final bot in _cache.values) {
      if (bot.enabled && bot.channels.contains(channel)) {
        return bot;
      }
    }
    return _cache.values.where((b) => b.enabled).firstOrNull;
  }

  Future<bool> upsertBot(BotDefinition bot) async {
    await init();
    _cache[bot.id] = bot.copyWith(updatedAt: DateTime.now());
    return _persist();
  }

  Future<bool> deleteBot(String id) async {
    await init();
    if (_cache.remove(id) != null) {
      return _persist();
    }
    return false;
  }

  Future<bool> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cache.values.map((b) => b.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
      return true;
    } catch (e) {
      debugPrint('[BotRepository] Error persistiendo bots: $e');
      return false;
    }
  }

  Future<void> _seedDefaultBots() async {
    final now = DateTime.now();
    final personalBot = BotDefinition(
      id: 'bot_personal_default',
      name: 'Nano Personal (EMMA)',
      role: BotRole.personal,
      description: 'Asistente personal con mi forma natural de escribir, memoria de contactos y acceso a Linux.',
      goal: BotRole.personal.defaultGoal,
      enabled: true,
      channels: const ['whatsapp', 'app_ui'],
      skillIds: BotSkillsCatalog.defaultSkillsForRole(BotRole.personal),
      permissions: BotPermissions.personalOwner(),
      policies: const {
        'adoptar_estilo_dueno': 'true',
        'privacidad_estricta': 'true',
      },
      createdAt: now,
      updatedAt: now,
    );

    final salesBot = BotDefinition(
      id: 'bot_sales_default',
      name: 'Nano Ventas & Negocio',
      role: BotRole.sales,
      description: 'Asesor comercial para WhatsApp Business con catálogo y validación de inventario en tiempo real.',
      goal: BotRole.sales.defaultGoal,
      enabled: false,
      channels: const ['whatsapp_business'],
      skillIds: BotSkillsCatalog.defaultSkillsForRole(BotRole.sales),
      permissions: BotPermissions.salesRestricted(),
      policies: const {
        'no_inventar_precios': 'true',
        'confirmar_stock_antes_de_prometer': 'true',
      },
      createdAt: now,
      updatedAt: now,
    );

    _cache[personalBot.id] = personalBot;
    _cache[salesBot.id] = salesBot;
    await _persist();
  }
}

final botRepositoryProvider = Provider<BotRepository>((ref) => BotRepository.instance);

final botsListProvider = FutureProvider<List<BotDefinition>>((ref) async {
  final repo = ref.watch(botRepositoryProvider);
  return repo.listBots();
});
