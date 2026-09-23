// model_catalog_types.dart — Entidades y auxiliares de filtrado para el catálogo neural.
// QUÉ HACE: Modela el DTO unificado UnifiedModelItem, estados visuales y algoritmo de filtrado.
// CÓMO FUNCIONA: Combina modelos de catálogo con modelos detectados localmente en SD/almacenamiento.
// POR QUÉ: Desacopla la lógica de datos de los widgets de presentación y mantiene archivos < 200 líneas.
library;

import '../../domain/detected_model.dart';
import '../../domain/local_model.dart';

/// DTO unificado que representa un modelo de catálogo o un archivo local escaneado.
class UnifiedModelItem {
  final LocalModel? catalog;
  final DetectedModel? detected;

  const UnifiedModelItem.catalog(this.catalog) : detected = null;
  const UnifiedModelItem.detected(this.detected) : catalog = null;

  bool get isCatalog => catalog != null;
  String get name => isCatalog ? catalog!.name : detected!.name;
  String get fileName => isCatalog ? catalog!.fileName : detected!.name;
  bool get isDownloading =>
      catalog?.downloadState == ModelDownloadState.downloading;

  double get sizeGb => isCatalog
      ? catalog!.sizeGb
      : (detected!.sizeBytes > 0
            ? detected!.sizeBytes / (1024 * 1024 * 1024)
            : 0.0);

  double get ramGb => isCatalog ? catalog!.ramGb : 0.0;
  bool get installed => isCatalog ? catalog!.installed : detected!.usable;
  String get format => isCatalog
      ? catalog!.quant
      : (detected!.format == DetectedModelFormat.gguf ? 'GGUF' : 'OTRO');

  String get company {
    if (!isCatalog) return 'Tarjeta SD / Local';
    final lower = catalog!.name.toLowerCase();
    if (lower.contains('deepseek')) return 'DeepSeek AI';
    if (lower.contains('qwen')) return 'Alibaba Qwen';
    if (lower.contains('llama')) return 'Meta Llama';
    if (lower.contains('gemma')) return 'Google Gemma';
    if (lower.contains('phi')) return 'Microsoft Phi';
    if (lower.contains('whisper')) return 'OpenAI Whisper';
    return 'Comunidad AI';
  }

  String get sectionTitle {
    if (!isCatalog) return 'ALMACENAMIENTO LOCAL • TARJETA SD';
    if (catalog!.isVoiceStt) return 'OPENAI WHISPER • TRANSCRIPCIÓN';
    if (catalog!.isMultimodal) return 'ALIBABA QWEN • VISIÓN ARTIFICIAL';
    final lower = catalog!.name.toLowerCase();
    if (lower.contains('coder')) return '$company • PROGRAMACIÓN';
    if (lower.contains('deepseek') || lower.contains('r1')) {
      return '$company • RAZONAMIENTO';
    }
    return '$company • MODELOS MÓVILES';
  }

  String get typeTag {
    if (!isCatalog) return 'SD';
    if (catalog!.isVoiceStt) return 'VOZ';
    if (catalog!.isMultimodal) return 'VISIÓN';
    final lower = catalog!.name.toLowerCase();
    if (lower.contains('coder')) return 'CODER';
    if (lower.contains('deepseek') || lower.contains('r1')) return 'RAZÓN';
    if (lower.contains('instruct')) return 'CHAT';
    return 'LLM';
  }
}

/// Helper para filtrar modelos por término de búsqueda y categoría seleccionada.
class ModelFilterHelper {
  static List<UnifiedModelItem> filter({
    required List<LocalModel> catalog,
    required List<DetectedModel> detected,
    required String query,
    required String filter,
  }) {
    final list = <UnifiedModelItem>[];
    if (filter != 'SD / Local') {
      list.addAll(catalog.map((m) => UnifiedModelItem.catalog(m)));
    }
    if (filter == 'Todos' || filter == 'SD / Local' || filter == 'Instalados') {
      list.addAll(detected.map((d) => UnifiedModelItem.detected(d)));
    }
    return list.where((item) {
      final matches =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.company.toLowerCase().contains(query);
      if (!matches) return false;
      return switch (filter) {
        'Instalados' => item.installed,
        'Qwen' => item.company.contains('Qwen'),
        'DeepSeek' => item.company.contains('DeepSeek'),
        'Llama' => item.company.contains('Llama'),
        'Gemma' => item.company.contains('Gemma'),
        'Phi' => item.company.contains('Phi'),
        'SD / Local' => !item.isCatalog,
        _ => true,
      };
    }).toList();
  }
}

/// Estados visuales de cada tarjeta en el catálogo
enum ModelUiStatus {
  active,
  installed,
  available,
  downloading,
  error,
  incompatible,
  runtimeUnavailable,
}
