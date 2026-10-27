// QUÉ: metadatos del catálogo separados por responsabilidad.
// CÓMO: extiende el DTO sin modificar archivos ni seleccionar motores.
// POR QUÉ: mantiene una sola clasificación y archivos breves.
part of 'model_catalog_types.dart';

extension ModelItemRuntime on UnifiedModelItem {
  /// Estado de integración comprobable en el runtime actual de Nano.
  bool get runtimeReady {
    if (!isCatalog) return false;
    final cat = catalog!;
    final n = cat.name.toLowerCase();
    if (cat.kind == ModelKind.llm) {
      return cat.backendType == ModelBackendType.gguf ||
          cat.backendType == ModelBackendType.litertlm ||
          cat.backendType == ModelBackendType.mnn;
    }
    if (cat.kind == ModelKind.voiceStt) {
      return cat.backendType == ModelBackendType.gguf && n.contains('whisper');
    }
    // El chat entrega OCR/etiquetas como texto: ningún VLM recibe aquí
    // los bytes de imagen. El archivo instalado no integra esa ruta.
    return false;
  }

  String get runtimeLabel {
    if (runtimeReady) {
      return catalog!.isVoiceStt
          ? 'Ruta de transcripción conectada'
          : 'Ruta de texto conectada · requiere carga';
    }
    if (categoryKey == 'local') {
      return 'GGUF local · tipo de tarea no identificado';
    }
    if (categoryKey == 'rag') {
      return 'Especializado · motor RAG pendiente';
    }
    if (categoryKey == 'agentes') {
      return 'Especializado · sin carga conversacional';
    }
    if (categoryKey.startsWith('voz')) {
      return 'Especializado · adaptador pendiente';
    }
    if (categoryKey == 'vision') {
      return 'VLM catalogado · entrada de imagen al chat pendiente';
    }
    if (categoryKey == 'ocr') {
      return 'PaddleOCR catalogado · runtime propio pendiente';
    }
    return 'Catálogo · runtime no verificado';
  }
}
