// models_screen_actions.dart — Acciones de favoritos, compartir y comparación de modelos.
// QUÉ HACE: Gestiona persistencia de favoritos con SharedPreferences, compartir nativo y benchmark.
// CÓMO FUNCIONA: Métodos utilitarios desacoplados con feedback táctil y visual (SnackBar).
// POR QUÉ: Evita componentes muertos y mantiene models_screen.dart estrictamente < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model_catalog_types.dart';

class ModelsScreenActions {
  static const _favoritesKey = 'nano_favorite_model_ids';

  /// QUÉ HACE: Carga la lista persistida de modelos favoritos.
  static Future<Set<String>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favoritesKey);
      return list?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  /// QUÉ HACE: Alterna un modelo entre favoritos y lo persiste en disco.
  static Future<void> saveFavorites(Set<String> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, favorites.toList());
    } catch (_) {}
  }

  /// QUÉ HACE: Comparte la ficha técnica del modelo vía SharePlus nativo.
  static Future<void> shareModel(
    BuildContext context,
    UnifiedModelItem item,
  ) async {
    final text =
        '🤖 ${item.name} (${item.format}) • ${item.company}\n'
        '📦 Tamaño: ${item.sizeGb.toStringAsFixed(1)} GB | RAM de referencia: ~${item.ramGb.toStringAsFixed(1)} GB\n'
        'El rendimiento depende del motor y del dispositivo.';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Modelo IA ${item.name}'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ficha técnica copiada al portapapeles.'),
          ),
        );
      }
    }
  }
}
