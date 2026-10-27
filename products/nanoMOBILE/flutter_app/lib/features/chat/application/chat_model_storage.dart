import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/model_path_support.dart';

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
      // La configuración actual manda; las claves antiguas solo sirven de respaldo.
      final rawSettings = prefs.getString('nanoai_settings');
      if (rawSettings != null && rawSettings.isNotEmpty) {
        try {
          final settings = (jsonDecode(rawSettings) as Map).cast<String, dynamic>();
          final configuredModel = settings['chatModelId'] as String? ?? '';
          final configuredPath = settings['chatModelPath'] as String?;
          if (configuredModel.isNotEmpty &&
              isRunnableModelPath(configuredPath)) {
            await saveLegacy(configuredModel, configuredPath!);
            return (model: configuredModel, path: configuredPath);
          }
        } on Object catch (error) {
          debugPrint('[ChatModelStorage] Settings de modelo inválido: ${error.runtimeType}');
        }
      }

      // Si Settings no apunta a un modelo utilizable, intenta recuperar la selección legacy.
      var saved = prefs.getString('nanoai_active_model');
      var savedPath = prefs.getString('nanoai_active_model_path');
      if (saved != null && saved.isNotEmpty) {
        if (isRunnableModelPath(savedPath)) {
          return (model: saved, path: savedPath!);
        }
        await prefs.remove('nanoai_active_model');
        await prefs.remove('nanoai_active_model_path');
      }

      // AUTO-DESCUBRIMIENTO HONESTO: Si no hay modelo seleccionado, buscar en el almacenamiento local
      final autoModel = await _discoverExistingModel();
      if (autoModel != null) {
        await saveLegacy(autoModel.model, autoModel.path);
        return autoModel;
      }
      return null;
    } catch (e) {
      debugPrint('[ChatModelStorage] Error recuperando modelo: $e');
      return null;
    }
  }

  /// Escanea directorios locales en busca de modelos descargados válidos (.gguf, .litertlm, .bin)
  Future<({String model, String path})?> _discoverExistingModel() async {
    try {
      final probeDirs = <String>[
        '/sdcard/Model',
        '/sdcard/NanoAI',
        '/sdcard/Android/data/dev.nanoai.mobile/files/nano/models',
      ];
      for (final dirPath in probeDirs) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.endsWith('.gguf') || name.endsWith('.litertlm')) {
            final stat = await entity.stat();
            if (stat.size > 50 * 1024 * 1024) {
              // Mayor a 50MB
              debugPrint(
                '[ChatModelStorage] Modelo autodescubierto: $name (${entity.path})',
              );
              return (model: name, path: entity.path);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatModelStorage] Error en autodescubrimiento: $e');
    }
    return null;
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
