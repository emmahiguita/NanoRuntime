// browser_ai_preferences.dart — Persistencia de preferencias del router de IA web.
// QUÉ HACE: Guarda y recupera el proveedor preferido y la lista de chats personalizados.
// CÓMO FUNCIONA: Utiliza SharedPreferences con claves tipadas y serialización JSON.
// POR QUÉ: Mantiene la configuración del usuario al reiniciar Nano AI.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/browser_ai_custom_provider_model.dart';

class BrowserAiPreferences {
  static const _keyPreferred = 'browser_ai_preferred_provider';
  static const _keyCustomProviders = 'browser_ai_custom_providers_json';

  /// Obtiene el identificador del proveedor preferido ('auto', 'chatgpt', 'kimi', etc.).
  static Future<String> getPreferredProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPreferred) ?? 'auto';
  }

  /// Guarda el identificador del proveedor preferido.
  static Future<void> setPreferredProviderId(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreferred, providerId);
  }

  /// Carga la lista de proveedores personalizados configurados por el usuario.
  static Future<List<BrowserAiCustomProviderModel>> loadCustomProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCustomProviders);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => BrowserAiCustomProviderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Guarda un nuevo proveedor personalizado.
  static Future<void> saveCustomProvider(BrowserAiCustomProviderModel model) async {
    final list = await loadCustomProviders();
    final updated = [...list.where((p) => p.id != model.id), model];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomProviders, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  /// Elimina un proveedor personalizado por su ID.
  static Future<void> removeCustomProvider(String id) async {
    final list = await loadCustomProviders();
    final updated = list.where((p) => p.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomProviders, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }
}

/// Estado reactivo del proveedor preferido en Riverpod.
final preferredAiProviderStateProvider = StateNotifierProvider<PreferredAiProviderNotifier, String>((ref) {
  return PreferredAiProviderNotifier();
});

class PreferredAiProviderNotifier extends StateNotifier<String> {
  PreferredAiProviderNotifier() : super('auto') {
    _init();
  }

  Future<void> _init() async {
    state = await BrowserAiPreferences.getPreferredProviderId();
  }

  Future<void> setPreferred(String id) async {
    state = id;
    await BrowserAiPreferences.setPreferredProviderId(id);
  }
}
