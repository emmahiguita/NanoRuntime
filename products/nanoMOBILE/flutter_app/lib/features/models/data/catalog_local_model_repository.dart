import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';
import 'package:nanoai/features/models/data/model_integrity.dart';
import 'mnn_omni_package.dart';

/// Repositorio honesto: el estado de descarga se decide contra el filesystem
/// real de la app (files/nano/models/), nunca contra una constante.
class CatalogLocalModelRepository implements LocalModelRepository {
  const CatalogLocalModelRepository();

  /// Directorio de archivos locales de modelos. Resuelto vía getFilesDir del
  /// runtime; null si el canal no está disponible (sin runtime → nada
  /// aparece instalado, honesto).
  static Future<String?> modelsDir() async {
    try {
      final base = await NanoRuntimeApi.instance.getFilesDir();
      if (base == null || base.isEmpty) return null;
      final cleanBase = base.endsWith('/nano') || base.endsWith(r'\nano')
          ? base
          : (base.endsWith('/') || base.endsWith(r'\')
                ? '${base}nano'
                : '$base/nano');
      return '$cleanBase/models';
    } catch (error) {
      debugPrint('[models] No se pudo resolver modelsDir: $error');
      return null;
    }
  }

  // QUÉ HACE: Devuelve la lista inicial síncrona de modelos del catálogo.
  // CÓMO FUNCIONA: Mapea NeuralCatalog.models a LocalModel sin esperar I/O de disco.
  // POR QUÉ: Garantiza que la pantalla nunca arranque vacía ni parpadee.
  static List<LocalModel> initialCatalog() {
    return NeuralCatalog.models
        .map((e) => _entryToModel(e, null, false))
        .toList();
  }

  @override
  Future<List<LocalModel>> listModels() async {
    try {
      final dirPath = await modelsDir();
      final models = <LocalModel>[];
      for (final entry in NeuralCatalog.models) {
        models.add(await _toModel(entry, dirPath));
      }
      return models;
    } catch (error, trace) {
      // Conserva el catálogo visible, pero registra la causa real para mantenimiento.
      debugPrint('[models] Falló la verificación del catálogo: $error\n$trace');
      return initialCatalog();
    }
  }

  Future<LocalModel> _toModel(LmCatalogEntry entry, String? dirPath) async {
    final path = dirPath == null
        ? null
        : '$dirPath${Platform.pathSeparator}${entry.file}';
    final installed = path != null && (entry.backendType == ModelBackendType.mnn
        ? await MnnOmniPackage.isInstalled(Directory(path))
        : await ModelIntegrity.verify(File(path), entry.sha256));
    return _entryToModel(entry, path, installed);
  }

  static LocalModel _entryToModel(
    LmCatalogEntry entry,
    String? destPath,
    bool installed,
  ) {
    return LocalModel(
      id: entry.file,
      name: entry.name,
      params: entry.params,
      quant: entry.quant,
      sizeGb: entry.sizeGb,
      ramGb: entry.ramGb,
      fileName: entry.file,
      description: _descriptionFor(entry.name),
      template: entry.template,
      tier: entry.tier,
      kind: entry.kind,
      downloadState: installed
          ? ModelDownloadState.installed
          : ModelDownloadState.notInstalled,
      progress: installed ? 1.0 : 0.0,
      url: entry.url,
      sha256: entry.sha256,
      backendType: entry.backendType,
      packageRevision: entry.packageRevision,
      localPath: installed ? destPath : null,
      active: false,
      loading: false,
      mmprojFile: entry.mmprojFile,
      mmprojUrl: entry.mmprojUrl,
      mmprojSha256: entry.mmprojSha256,
    );
  }

  // Las fichas distinguen compatibilidad publicada de mediciones del Oppo.
  static String _descriptionFor(String name) => switch (name) {
    'Qwen3-0.6B-Instruct (LiteRT)' =>
      'Qwen3 INT4 con LiteRT-LM. Es la opción ligera; la velocidad depende del dispositivo y de la sesión.',
    'Qwen2.5-1.5B-Instruct (LiteRT)' =>
      'Paquete LiteRT-LM Q8 oficial, contexto de 4096. El proveedor midió hasta 2.2 GB de pico en otro teléfono; MediaTek sin medir.',
    'Gemma-4-E2B-it (LiteRT)' =>
      'LiteRT-LM para texto. La estimación declarada de RAM es 3.5 GB; no se ha validado en este Oppo MediaTek.',
    'Whisper-Tiny (Voz Local)' =>
      'Transcripción local con el modelo Tiny de whisper.cpp.',
    'Whisper-Base (Voz Local)' =>
      'Transcripción local con el modelo Base de whisper.cpp.',
    'Qwen2.5-Omni-3B (MNN)' =>
      'Paquete oficial MNN CPU, revisión fija. La ruta móvil actual responde texto; imagen y audio no están habilitados. Consumo y velocidad pendientes de medir en este teléfono.',
    'LFM2.5-230M (LiteRT)' =>
      'Modelo compacto de Liquid AI convertido por litert-community. Paquete INT8 para texto; RAM estimada y velocidad pendiente de medir.',
    'DeepSeek-R1-Distill-Qwen-1.5B (LiteRT)' =>
      'Modelo de razonamiento de DeepSeek en el paquete LiteRT-LM de AI Edge Gallery. RAM estimada; velocidad pendiente de medir en este teléfono.',
    'Qwen2.5-0.5B-Instruct (GGUF Q4_0)' =>
      'Qwen2.5 0.5B oficial en Q4_0 para llama.cpp. RAM estimada; velocidad y consumo pendientes de medir en este teléfono.',
    'Qwen2.5-1.5B-Instruct (GGUF Q4_0)' =>
      'Qwen2.5 1.5B oficial en Q4_0 para llama.cpp. Alternativa CPU; no se garantiza que supere la variante LiteRT.',
    'Llama-3.2-1B-Instruct (GGUF Q4_0)' =>
      'Modelo Meta Llama 3.2 con conversión GGUF Q4_0 de bartowski. RAM estimada y velocidad pendiente de medir.',
    _ => 'Recurso local del catálogo; revisa formato y tamaño antes de instalar.',
  };
}
