// browser_external_app_behavior.dart
//
// QUÉ HACE: expone el modo configurado para deep links de apps externas
// (STAY_IN_WEB por defecto) y lo persiste entre sesiones.
//
// CÓMO FUNCIONA: StateNotifier con SharedPreferences; al arrancar restaura el
// valor guardado y `cycle()` rota entre los tres modos desde el menú.
//
// POR QUÉ: el usuario debe poder elegir cómo reacciona el navegador ante
// "Abrir en app" sin tocar el firewall ni fragmentar la política de TikTok.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tiktok_web_policy.dart';

class ExternalAppBehaviorNotifier extends StateNotifier<ExternalAppBehavior> {
  ExternalAppBehaviorNotifier() : super(ExternalAppBehavior.stayInWeb) {
    _restore();
  }

  static const String _prefsKey = 'browser_external_app_behavior';

  /// Restaura el modo guardado; si falla, mantiene el default seguro.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = ExternalAppBehavior.fromId(prefs.getString(_prefsKey));
      if (mounted) state = saved;
    } catch (_) {
      // Sin preferencias disponibles se mantiene STAY_IN_WEB.
    }
  }

  Future<void> setBehavior(ExternalAppBehavior behavior) async {
    state = behavior;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, behavior.id);
    } catch (_) {
      // La selección vive en memoria si el disco no está disponible.
    }
  }

  /// Rota al siguiente modo para el toggle del menú de opciones.
  Future<void> cycle() => setBehavior(
    ExternalAppBehavior.values[(state.index + 1) % ExternalAppBehavior.values.length],
  );
}

final browserExternalAppBehaviorProvider =
    StateNotifierProvider<ExternalAppBehaviorNotifier, ExternalAppBehavior>(
  (ref) => ExternalAppBehaviorNotifier(),
);
