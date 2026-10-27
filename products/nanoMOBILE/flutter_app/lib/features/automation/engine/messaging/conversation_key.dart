/// API pública de identidad conversacional.
///
/// QUÉ HACE: expone modelo, resolución y canal desde un punto estable.
/// CÓMO: delega cada responsabilidad en un archivo menor a 200 líneas.
/// POR QUÉ: mantiene compatibles los imports existentes sin mezclar dominio,
/// extracción de notificaciones y catálogo de plataformas.
library;

export 'conversation_identity_model.dart';
export 'conversation_identity_resolver.dart';
export 'messaging_channel.dart';
