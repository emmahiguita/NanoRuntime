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
    try {
      final base = await NanoRuntimeApi.instance.getFilesDir();
      if (base == null || base.isEmpty) return null;
      final cleanBase = base.endsWith('/nano') || base.endsWith(r'\nano')
          ? base
          : (base.endsWith('/') || base.endsWith(r'\') ? '${base}nano' : '$base/nano');
      return '$cleanBase/models';
    } catch (_) {
      return null;
    }
  }

  // QUÉ HACE: Devuelve la lista inicial síncrona de modelos del catálogo.
  // CÓMO FUNCIONA: Mapea NeuralCatalog.models a LocalModel sin esperar I/O de disco.
  // POR QUÉ: Garantiza que la pantalla nunca arranque vacía ni parpadee.
  static List<LocalModel> initialCatalog() {
    return NeuralCatalog.models.map((e) => _entryToModel(e, null, false)).toList();
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
    } catch (_) {
      return initialCatalog();
    }
  }

  Future<LocalModel> _toModel(LmCatalogEntry entry, String? dirPath) async {
    final dest = dirPath == null
        ? null
        : File('$dirPath${Platform.pathSeparator}${entry.file}');
    final installed =
        dest != null && await ModelIntegrity.verify(dest, entry.sha256);
    return _entryToModel(entry, dest?.path, installed);
  }

  static LocalModel _entryToModel(LmCatalogEntry entry, String? destPath, bool installed) {
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
      localPath: installed ? destPath : null,
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
    // MODELS-CAT-04: ultraligeros 2026
    'LFM2.5-350M-Q4_K_M' =>
      'Motor ultraligero LiquidAI (350M, conv+atención). Comprensión multilingüe en <500 MB RAM.',
    'LFM2.5-350M-QAD' =>
      'LFM2.5-350M con cuantización calibrada QAD: máxima calidad para 220 MB de archivo.',
    'Qwen3-0.6B-Q8_0' =>
      'Qwen3-0.6B en máxima precisión (Q8_0). 640 MB · 0.9 GB RAM · Apache 2.0.',
    'Qwen3.5-0.8B-Q4_K_M' =>
      'Qwen 3.5 generación 2026 (0.8B). Conversación en español, comprensión e instrucciones. 580 MB · <900 MB RAM.',
    _ => 'Cuantización y tamaño reales de HuggingFace.',
  };
}
