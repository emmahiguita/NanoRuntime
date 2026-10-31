part of 'catalog_models.dart';

/// Tipos semanticos del catalogo; mismos contratos publicos de sus consumidores.
enum ModelTier {
  /// Opción ligera que se puede ofrecer como predeterminada tras validarla.
  interactive,

  /// Recurso avanzado: el usuario lo elige por memoria o contexto.
  deep,

  /// Modelo pesado: no se selecciona por defecto en un móvil.
  extreme,
}

/// Función que el modelo puede cumplir; evita enviar recursos especializados al chat.
/// Los embeddings producen vectores y no respuestas de texto conversacional.
enum ModelKind {
  llm,
  wakeWord,
  voiceStt,
  voiceTts,
  speakerDiarization,
  multimodalVision,
  imageOcr,
  embedding,
}

/// Formato y motor de inferencia nativo que consume el archivo del modelo.
enum ModelBackendType { gguf, litertlm, mnn }
