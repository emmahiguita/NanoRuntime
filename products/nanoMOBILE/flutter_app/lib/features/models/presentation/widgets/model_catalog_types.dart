// model_catalog_types.dart — DTO unificado + filtrado para el catálogo neural.
// QUÉ HACE: Modela UnifiedModelItem, estados visuales y algoritmo de filtrado con ordenamiento.
// CÓMO FUNCIONA: Combina catálogo y modelos detectados; instalados siempre primero.
// POR QUÉ: Desacopla lógica de datos de los widgets; mantiene < 200 líneas (SOLID/SRP).
library;

import '../../../../core/models/catalog_models.dart'
    show ModelKind, ModelBackendType;
import '../../domain/detected_model.dart';
import '../../domain/local_model.dart';

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

  // QUÉ HACE: Resuelve la empresa/familia del modelo por nombre.
  // POR QUÉ: Centraliza la detección de familia para secciones y filtros.
  String get company {
    if (!isCatalog) return 'Tarjeta SD / Local';
    final n = catalog!.name.toLowerCase();
    // Una destilación de Qwen pertenece a DeepSeek: comprobarla antes de Qwen.
    if (n.contains('deepseek')) return 'DeepSeek AI';
    if (n.contains('lfm') || n.contains('liquid')) return 'Liquid AI';
    if (n.contains('qwen')) return 'Alibaba Qwen';
    if (n.contains('gemma')) return 'Google Gemma';
    if (n.contains('whisper')) return 'OpenAI Whisper';
    if (n.contains('llama')) return 'Meta Llama';
    return 'Comunidad AI';
  }

  // QUÉ HACE: Genera el título de sección agrupada (familia + función).
  // POR QUÉ: Cada familia debe aparecer en su propia sección, no mezclada.
  String get sectionTitle {
    if (!isCatalog) return 'ALMACENAMIENTO LOCAL • TARJETA SD';
    final cat = catalog!;
    if (cat.isVoiceStt) return 'OPENAI WHISPER • TRANSCRIPCIÓN DE VOZ';
    if (cat.kind == ModelKind.wakeWord) return 'WAKE WORD • ACTIVACIÓN LOCAL';
    if (cat.isMultimodal) return 'VISIÓN ARTIFICIAL • MULTIMODAL';
    final n = cat.name.toLowerCase();
    if (n.contains('lfm') || n.contains('liquid')) {
      return 'LIQUID AI • ULTRALIGERO EDGE';
    }
    if (n.contains('deepseek') || n.contains('r1')) {
      return 'DEEPSEEK AI • RAZONAMIENTO';
    }
    if (n.contains('coder')) return 'ALIBABA QWEN • PROGRAMACIÓN';
    if (n.contains('moondream')) return 'MOONDREAM • VISIÓN COMPACTA';
    if (n.contains('ministral') || n.contains('mistral')) {
      return 'MISTRAL AI • CONVERSACIÓN';
    }
    return '$company • MODELOS MÓVILES';
  }

  // QUÉ HACE: Etiqueta corta de la tarjeta.
  // NANO = recomendado para Nano Personal (ultrapequeño, < 1B params).
  // EDGE = arquitectura edge-first (LFM).
  String get typeTag {
    if (!isCatalog) return 'SD';
    final cat = catalog!;
    if (cat.isVoiceStt) return 'VOZ';
    if (cat.kind == ModelKind.wakeWord) return 'WAKE';
    if (cat.isMultimodal) return 'VISIÓN';
    final n = cat.name.toLowerCase();
    if (cat.backendType == ModelBackendType.litertlm) return 'LITERT';
    if (cat.backendType == ModelBackendType.mnn) return 'MNN';
    if (n.contains('lfm')) return 'EDGE';
    if (n.contains('coder')) return 'CODER';
    if (n.contains('deepseek') || n.contains('r1')) return 'RAZÓN';
    if (n.contains('0.6b') || n.contains('0.8b') || n.contains('350m')) {
      return 'NANO';
    }
    if (n.contains('instruct')) return 'CHAT';
    return 'LLM';
  }

  // El badge aplica al único modelo marcado tras medirlo en el Oppo objetivo.
  // POR QUÉ: UI muestra badge ⭐ y lo ubica en la sección de modelos óptimos para hardware móvil.
  bool get isRecommendedForNano {
    return isCatalog && catalog!.name == 'Qwen3-0.6B-Instruct (LiteRT)';
  }

  // QUÉ HACE: true si es modelo especializado (Whisper Voz, Visión o Coder).
  // POR QUÉ: Permite agrupar herramientas de funciones dedicadas con separador propio.
  bool get isSpecialized {
    if (!isCatalog) return false;
    final cat = catalog!;
    return cat.isVoiceStt || cat.isMultimodal || cat.kind == ModelKind.wakeWord;
  }
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
    if (filter == 'Todos' || filter == 'SD / Local' || filter == 'Instalados' || filter == 'Favoritos') {
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
        'Favoritos' => favorites?.contains(item.name) ?? false,
        'Descargas' => item.isDownloading || item.installed,
        'Qwen' => item.company.contains('Qwen'),
        'Gemma' => item.company.contains('Gemma'),
        'Liquid AI' => item.company == 'Liquid AI',
        'DeepSeek' => item.company == 'DeepSeek AI',
        'Voz' => item.isCatalog && item.catalog!.isVoiceStt,
        'SD / Local' => !item.isCatalog,
        _ => true,
      };
    }).toList();

    // Instalados → recomendados → resto (orden estable dentro de cada grupo).
    filtered.sort((a, b) {
      if (a.installed != b.installed) return a.installed ? -1 : 1;
      if (a.isRecommendedForNano != b.isRecommendedForNano) {
        return a.isRecommendedForNano ? -1 : 1;
      }
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
