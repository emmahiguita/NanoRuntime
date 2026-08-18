import 'dart:io';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';

/// Repositorio honesto: el estado de descarga se decide contra el filesystem
/// real de la app (files/nano/models/), nunca contra una constante.
class CatalogLocalModelRepository implements LocalModelRepository {
  const CatalogLocalModelRepository();

  /// Directorio de modelos GGUF de la app. Resuelto vía getFilesDir del
  /// runtime; null si el canal no está disponible (sin runtime → nada
  /// aparece instalado, honesto).
  static Future<String?> modelsDir() async {
    final base = await NanoRuntimeApi.instance.getFilesDir();
    if (base == null || base.isEmpty) return null;
    return '$base/nano/models';
  }

  @override
  Future<List<LocalModel>> listModels() async {
    final dirPath = await modelsDir();
    return [
      for (final entry in NeuralCatalog.models) _toModel(entry, dirPath),
    ];
  }

  LocalModel _toModel(LmCatalogEntry entry, String? dirPath) {
    final dest = dirPath == null
        ? null
        : File('$dirPath${Platform.pathSeparator}${entry.file}');
    // Evidencia del filesystem: solo installed si el GGUF final existe.
    final installed =
        dest != null && dest.existsSync() && dest.lengthSync() > 0;
    final destPath = installed ? dest.path : null;
    return LocalModel(
      // Id estable: el nombre de archivo no cambia al reordenar el catálogo
      // (los ids `m$index` cambiaban y un activo podía apuntar a otro modelo).
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
      downloadState: installed
          ? ModelDownloadState.installed
          : ModelDownloadState.notInstalled,
      progress: installed ? 1.0 : 0.0,
      url: entry.url,
      sha256: entry.sha256,
      localPath: destPath,
      active: false,
      loading: false,
    );
  }

  static String _descriptionFor(String name) => switch (name) {
    'Qwen2.5-1.5B-Instruct' =>
      'Ligero y rápido, ideal para CPU móvil. Carga por defecto.',
    'Qwen2.5-3B-Instruct' =>
      'Mejor calidad de 3B: tarda más pero responde mejor.',
    'Qwen3.5-4B' =>
      'Generación 2026 (linear attention). Recomendado para dispositivos con 4GB de RAM.',
    'Qwen3.5-4B-Q4_K_M' =>
      'Variante Q4_K_M: máxima calidad de la clase 4B.',
    'DeepSeek-R1-Distill-Qwen-7B' =>
      'Razonamiento profundo. Pesado para móvil.',
    'DeepSeek-R1-Distill-Qwen-7B-Q2' =>
      'Variante Q2_K del 7B: menor RAM, calidad reducida.',
    _ => 'Cuantización y tamaño reales de HuggingFace.',
  };
}
