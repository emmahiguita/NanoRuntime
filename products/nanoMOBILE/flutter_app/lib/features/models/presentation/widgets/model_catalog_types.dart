// model_catalog_types.dart — DTO unificado + filtrado para el catálogo neural.
// QUÉ HACE: Modela UnifiedModelItem, estados visuales y algoritmo de filtrado con ordenamiento.
// CÓMO FUNCIONA: Combina catálogo y modelos detectados; instalados siempre primero.
// POR QUÉ: Desacopla lógica de datos de los widgets; mantiene < 200 líneas (SOLID/SRP).
library;

import '../../../../core/models/catalog_models.dart'
    show ModelKind, ModelBackendType;
import '../../domain/detected_model.dart';
import '../../domain/local_model.dart';

part 'model_item_categories.part.dart';
part 'model_item_runtime.part.dart';
part 'model_item_identity.part.dart';
part 'model_item_narrative.part.dart';
part 'model_qwen_information.part.dart';

/// DTO unificado: modelo de catálogo o archivo local escaneado.
class UnifiedModelItem {
  final LocalModel? catalog;
  final DetectedModel? detected;

  const UnifiedModelItem.catalog(this.catalog) : detected = null;
  const UnifiedModelItem.detected(this.detected) : catalog = null;

  bool get isCatalog => catalog != null;
  String get name => isCatalog ? catalog!.name : detected!.name;
  String get fileName => isCatalog ? catalog!.fileName : detected!.name;
  // Verificar sigue ocupando la descarga: ofrece cancelar, nunca descargar otra vez.
  bool get isDownloading => catalog?.isDownloading ?? false;

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
}

/// Filtrado + ordenamiento: instalados primero, luego recomendados, luego disponibles.
class ModelFilterHelper {
  // QUÉ HACE: Filtra por query y categoría; ordena instalados al tope.
  // CÓMO FUNCIONA: Lista unificada → where() → sort(instalados→recomendados→resto).
  // POR QUÉ: El usuario ve inmediatamente lo que puede usar sin scrollear.
  static List<UnifiedModelItem> filter({
    required List<LocalModel> catalog,
    required List<DetectedModel> detected,
    required String query,
    required String filter,
    Set<String>? favorites,
  }) {
    final list = <UnifiedModelItem>[];
    if (filter != 'SD / Local') {
      list.addAll(catalog.map((m) => UnifiedModelItem.catalog(m)));
    }
    if (filter == 'Todos' ||
        filter == 'SD / Local' ||
        filter == 'Instalados' ||
        filter == 'Favoritos') {
      list.addAll(detected.map((d) => UnifiedModelItem.detected(d)));
    }

    final filtered = list.where((item) {
      final q = query.toLowerCase();
      final matches =
          q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.company.toLowerCase().contains(q);
      if (!matches) return false;
      return switch (filter) {
        'Instalados' => item.installed,
        'AI Chat' ||
        'Multimodales' ||
        'Razonamiento' ||
        'Programación' ||
        'Imagen y documentos' ||
        'Transcripción de audio' ||
        'Síntesis de voz' ||
        'Separación de hablantes' ||
        'Memoria y RAG' ||
        'Agentes y acciones' => item.categoryLabel == filter,
        'Favoritos' => favorites?.contains(item.name) ?? false,
        'Descargas' =>
          item.isDownloading ||
              item.catalog?.downloadState == ModelDownloadState.failed,
        'Qwen' => item.company.contains('Qwen'),
        'Gemma' => item.company.contains('Gemma'),
        'Granite' => item.company.contains('Granite'),
        'Liquid AI' => item.company == 'Liquid AI',
        'DeepSeek' => item.company == 'DeepSeek AI',
        'Visión / OCR' =>
          item.isCatalog &&
              (item.catalog!.isMultimodal ||
                  item.catalog!.kind == ModelKind.imageOcr),
        'OCR de documentos' =>
          item.isCatalog && item.catalog!.kind == ModelKind.imageOcr,
        'RAG' => item.isCatalog && item.catalog!.kind == ModelKind.embedding,
        'Voz' => item.isCatalog && item.catalog!.isVoiceStt,
        'SD / Local' => !item.isCatalog,
        _ => true,
      };
    }).toList();

    // Instalados primero; dentro de cada grupo se conserva el orden del catálogo.
    filtered.sort((a, b) {
      if (a.installed != b.installed) return a.installed ? -1 : 1;
      return 0;
    });
    return filtered;
  }
}

/// Estados visuales de cada tarjeta en el catálogo.
enum ModelUiStatus {
  active,
  installed,
  available,
  downloading,
  error,
  incompatible,
  runtimeUnavailable,
}
