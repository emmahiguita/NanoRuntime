import 'dart:io';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';
import 'package:nanoai/features/models/data/model_integrity.dart';

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
    final models = <LocalModel>[];
    // Los manifests son baratos; instalaciones heredadas requieren SHA-256.
    // Se procesan en serie para no hashear varios GGUF a la vez en el móvil.
    for (final entry in NeuralCatalog.models) {
      models.add(await _toModel(entry, dirPath));
    }
    return models;
  }

  Future<LocalModel> _toModel(LmCatalogEntry entry, String? dirPath) async {
    final dest = dirPath == null
        ? null
        : File('$dirPath${Platform.pathSeparator}${entry.file}');
    // Un nombre y un tamaño no prueban integridad. Instalaciones antiguas se
    // verifican una vez; después el manifiesto evita hashear varios GB al abrir.
    final installed =
        dest != null && await ModelIntegrity.verify(dest, entry.sha256);
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
      kind: entry.kind,
      downloadState: installed
          ? ModelDownloadState.installed
          : ModelDownloadState.notInstalled,
      progress: installed ? 1.0 : 0.0,
      url: entry.url,
      sha256: entry.sha256,
      localPath: destPath,
      active: false,
      loading: false,
      mmprojFile: entry.mmprojFile,
      mmprojUrl: entry.mmprojUrl,
      mmprojSha256: entry.mmprojSha256,
    );
  }

  static String _descriptionFor(String name) => switch (name) {
    'Qwen2.5-1.5B-Instruct' =>
      'Ligero y rápido, ideal para CPU móvil. Carga por defecto.',
    'Qwen2.5-3B-Instruct' =>
      'Mejor calidad de 3B: tarda más pero responde mejor.',
    'Qwen3.5-4B' =>
      'Generación 2026 (linear attention). Recomendado para dispositivos con 4GB de RAM.',
    'Qwen3.5-4B-Q4_K_M' => 'Variante Q4_K_M: máxima calidad de la clase 4B.',
    'DeepSeek-R1-Distill-Qwen-7B' =>
      'Razonamiento profundo. Pesado para móvil.',
    'DeepSeek-R1-Distill-Qwen-7B-Q2' =>
      'Variante Q2_K del 7B: menor RAM, calidad reducida.',
    'LFM2.5-1.2B-Instruct-Q4_0-QAD' =>
      'Conversación permanente ultra-rápida. Diseñado para background 24/7 y móviles de 4GB.',
    'Qwen3.5-2B-Q4_K_M' =>
      'Comprensión semántica, extracción de entidades y análisis para móviles equilibrados.',
    'LFM2.5-1.2B-Thinking' =>
      'Razonamiento profundo bajo demanda (<think>) ultraligero y de bajo impacto de batería.',
    'LFM2.5-2.6B-Q4_0-QAD' =>
      'Agentic premium para ejecución y herramientas multi-paso (2.2GB RAM).',
    'Gemma-3n-E2B-IT' =>
      'Modelo multimodal; Nano conecta ahora la ruta de texto, no la entrada visual.',
    'Hey Mycroft (wake word)' =>
      'Detector local de palabra de activación; requiere un runtime de audio compatible.',
    'Whisper-Tiny (Voz Local)' =>
      'Transcripción de voz ultra-rápida (75MB) en CPU móvil con whisper.cpp.',
    'Whisper-Base (Voz Local)' =>
      'Reconocimiento de voz de alta precisión para dictado y comandos locales.',
    'Moondream2-1.8B-Vision' =>
      'Modelo multimodal compacto: comprensión visual y preguntas sobre imágenes locales.',
    _ => 'Cuantización y tamaño reales de HuggingFace.',
  };
}
