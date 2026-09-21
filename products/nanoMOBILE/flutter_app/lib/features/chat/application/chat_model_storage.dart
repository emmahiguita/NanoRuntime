import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento y persistencia local de la configuración del modelo de chat.
///
/// **QUÉ HACE:**
/// Guarda y restaura las claves del modelo activo (`nanoai_active_model`,
/// `nanoai_active_model_path`) tanto en `SharedPreferences` legacy como en el
/// payload JSON de `SettingsRepository`.
///
/// **CÓMO FUNCIONA:**
/// - En lectura: verifica la existencia física del archivo GGUF antes de aceptarlo.
/// - En escritura: realiza escrituras no bloqueantes en SharedPreferences.
///
/// **POR QUÉ:**
/// Extrae la interacción con disco y SharedPreferences fuera del ciclo de vida del
/// motor (`ChatModelService`), previniendo condiciones de carrera y simplificando el testing.
class ChatModelStorage {
  const ChatModelStorage();

  /// Recupera el par (modelo, ruta) guardado en disco. Retorna null si no existe o fue borrado.
  Future<({String model, String path})?> loadSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var saved = prefs.getString('nanoai_active_model');
      var savedPath = prefs.getString('nanoai_active_model_path');

      // Settings es la fuente que consume el arranque headless
      if ((saved == null || saved.isEmpty) || (savedPath == null || savedPath.trim().isEmpty)) {
        final rawSettings = prefs.getString('nanoai_settings');
        if (rawSettings != null && rawSettings.isNotEmpty) {
          final settings = (jsonDecode(rawSettings) as Map).cast<String, dynamic>();
          saved = settings['chatModelId'] as String? ?? saved;
          savedPath = settings['chatModelPath'] as String? ?? savedPath;
        }
      }
      if (saved == null || saved.isEmpty) return null;

      final exists = savedPath != null && savedPath.trim().isNotEmpty && await File(savedPath).exists();
      if (!exists) {
        await prefs.remove('nanoai_active_model');
        await prefs.remove('nanoai_active_model_path');
        return null;
      }
      return (model: saved, path: savedPath);
    } catch (e) {
      debugPrint('[ChatModelStorage] Error recuperando modelo: $e');
      return null;
    }
  }

  /// Guarda en SharedPreferences legacy el modelo y ruta activos.
  Future<void> saveLegacy(String name, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nanoai_active_model', name);
      if (path.isNotEmpty) {
        await prefs.setString('nanoai_active_model_path', path);
      } else {
        await prefs.remove('nanoai_active_model_path');
      }
    } catch (e) {
      debugPrint('[ChatModelStorage] Error persistencia legacy: $e');
    }
  }
}
