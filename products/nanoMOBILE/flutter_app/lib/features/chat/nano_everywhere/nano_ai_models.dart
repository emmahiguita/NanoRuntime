// nano_ai_models.dart — Modelos de datos y puertos para Nano Everywhere.
// QUÉ: Enums, entidades inmutables y contratos (interfaces) del sistema flotante.
// CÓMO: Enums puros; clases @immutable; interfaces abstractas para inyección.
// POR QUÉ: Separar contratos de implementación (SOLID-D: dependencia de abstracciones).
import 'package:flutter/foundation.dart';

/// Modos de consulta disponibles en el panel flotante.
enum NanoMode { quick, compare, debate, action, media }

/// Tipo de recurso multimedia identificado para descarga inteligente.
enum NanoMediaType { video, image, audio, document }

/// Recurso multimedia descubierto en una URL o página.
@immutable
class NanoMediaResource {
  const NanoMediaResource({
    required this.url,
    required this.type,
    required this.title,
    this.estimatedBytes,
    this.quality,
    this.sourceUrl,
  });

  final String url;
  final NanoMediaType type;
  final String title;
  final int? estimatedBytes;
  final String? quality;
  final String? sourceUrl;

  String get typeLabel => switch (type) {
    NanoMediaType.video => 'Vídeo',
    NanoMediaType.image => 'Imagen',
    NanoMediaType.audio => 'Audio',
    NanoMediaType.document => 'Documento',
  };
}

/// Estado visible del búho animado — dirige sprites y efectos.
enum NanoActivity {
  idle,
  listening,
  thinking,
  comparing,
  debating,
  acting,
  success,
  error,
  sleep,
  fly,
}

/// Categoría de proveedor para controlar qué flujo de consulta se usa.
enum NanoProviderKind { local, approvedWeb, nativeApp }

/// Firma de función para consultar un proveedor de IA de forma asíncrona.
typedef NanoAsk = Future<String> Function(String prompt);

/// Descriptor inmutable de un proveedor de IA (Gemini, GPT, local…).
@immutable
class NanoProvider {
  const NanoProvider({
    required this.id,
    required this.name,
    required this.kind,
    this.ask,
    this.androidPackage,
  });

  final String id;
  final String name;
  final NanoProviderKind kind;

  /// Callback de consulta programática; null si el proveedor es una app nativa.
  final NanoAsk? ask;

  /// Paquete Android para handoff con Intent.ACTION_SEND (ej: com.openai.chatgpt).
  final String? androidPackage;

  /// Solo los proveedores web/local con [ask] pueden recibir consultas directas.
  bool get supportsProgrammaticQuery =>
      kind != NanoProviderKind.nativeApp && ask != null;
}

/// Resultado de una consulta a un proveedor; incluye ronda para debates.
@immutable
class NanoAnswer {
  const NanoAnswer({
    required this.provider,
    required this.requestId,
    this.text = '',
    this.error,
    this.round = 1,
  });

  final NanoProvider provider;
  final int requestId;
  final String text;
  final String? error;

  /// Ronda 1 = respuesta inicial; Ronda 2 = réplica de debate.
  final int round;

  bool get ok => error == null && text.trim().isNotEmpty;
}

/// Informa al diálogo que se necesita una acción humana, como iniciar sesión.
@immutable
class NanoUserActionRequiredException implements Exception {
  const NanoUserActionRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Puerto para compartir prompts con apps nativas de IA (ChatGPT, Gemini app…).
/// No lee respuestas: solo hace handoff vía Intent.ACTION_SEND.
abstract interface class NanoNativeAiPort {
  Future<bool> sharePrompt(String androidPackage, String prompt);
}

/// Puerto al motor de automatización ya existente (AgentToolDispatcher).
abstract interface class NanoActionPort {
  /// Valida permisos, ejecuta y verifica el objetivo con el motor real.
  Future<String> executeAuthorizedGoal(String goal);
}
