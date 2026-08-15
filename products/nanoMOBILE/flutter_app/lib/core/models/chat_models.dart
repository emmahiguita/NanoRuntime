/// Modelos de datos del chat (estado, mensajes, enums).
///
/// Extraído de app_providers.dart (SRP). Clases puras sin dependencia de
/// Riverpod ni persistencia — solo datos e inmutabilidad.
enum ModelConnectionState { ready, loadingModel, noModel, error }

enum MessageSender { user, ai }

enum MessageStatus { sending, sent, error }

/// Formato de chat template que usa cada familia de modelos.
/// Los GGUF de Qwen usan `<|im_start|>/<|im_end|>` (ChatML-like).
/// Los GGUF de DeepSeek-R1 usan `<｜begin▁of▁sentence｜>/<｜end▁of▁sentence｜>`.
enum ChatTemplate { qwen, deepseek }

/// Adjunto pendiente de envío: un archivo textual elegido en el composer.
///
/// Solo [name] y [content] viven aquí; el contenido se inyecta al prompt de
/// la generación que lo consume y nunca se persiste en el historial
/// (protege SharedPreferences y la ventana de contexto de los GGUF).
class ChatAttachment {
  final String name;
  final String content;

  const ChatAttachment({required this.name, required this.content});
}

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final double? tps;
  final MessageStatus status;

  /// Nombres de los adjuntos que viajaron con este mensaje user (solo para
  /// mostrar chips tras recargar la app; el contenido no se persiste).
  final List<String> attachmentNames;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.tps,
    this.status = MessageStatus.sent,
    this.attachmentNames = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'tps': tps,
    'status': status.name,
    'attachmentNames': attachmentNames,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    sender: MessageSender.values.byName(json['sender'] as String),
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    tps: (json['tps'] as num?)?.toDouble(),
    status: MessageStatus.values.byName(json['status'] as String),
    attachmentNames:
        (json['attachmentNames'] as List?)?.cast<String>() ?? const [],
  );
}

/// Sentinel para distinguir "no pasado" de "null explícito" en [copyWith].
const Object _sentinel = Object();

class ChatState {
  final List<ChatMessage> messages;
  final String input;
  final bool generating;
  final String activeModel;

  /// Ruta absoluta del GGUF instalado del modelo activo (null si el modelo
  /// no está instalado). La pasa ChatNotifier al arranque del motor.
  final String? activeModelPath;
  final ModelConnectionState connection;
  final List<String> availableModels;
  final bool showModelSelector;
  final bool engineOnline;
  final double? liveTps;

  /// Texto parcial de la generación streaming en curso. Vacío si no hay
  /// generación activa o si aún no llegó el primer token.
  final String streamingText;

  /// Adjuntos pendientes de envío (máx 3). Se inyectan al prompt de la
  /// siguiente generación y se consumen; no se persisten.
  final List<ChatAttachment> attachments;

  /// Tool-calling: nombre de la herramienta que espera confirmación del
  /// usuario (política externalWrite). Null = nada pendiente. La UI muestra
  /// el diálogo y llama a approvePendingTool/rejectPendingTool.
  final String? pendingTool;

  /// Descripción legible de la herramienta pendiente (para el diálogo).
  final String? pendingToolDescription;

  const ChatState({
    this.messages = const [],
    this.input = '',
    this.generating = false,
    this.activeModel = 'Sin modelo',
    this.activeModelPath,
    this.connection = ModelConnectionState.noModel,
    this.availableModels = const [],
    this.showModelSelector = false,
    this.engineOnline = false,
    this.liveTps,
    this.streamingText = '',
    this.attachments = const [],
    this.pendingTool,
    this.pendingToolDescription,
  });

  /// [copyWith] con soporte para limpiar campos nullable a `null`.
  ///
  /// Campos nullable usan `Object?` + sentinel: pasar `null` explícito
  /// LIMPIA el campo; no pasar nada lo preserva. Esto corrige el bug donde
  /// `copyWith(pendingTool: null)` no tenía efecto.
  ChatState copyWith({
    List<ChatMessage>? messages,
    String? input,
    bool? generating,
    String? activeModel,
    Object? activeModelPath = _sentinel,
    ModelConnectionState? connection,
    List<String>? availableModels,
    bool? showModelSelector,
    bool? engineOnline,
    Object? liveTps = _sentinel,
    String? streamingText,
    List<ChatAttachment>? attachments,
    Object? pendingTool = _sentinel,
    Object? pendingToolDescription = _sentinel,
  }) => ChatState(
    messages: messages ?? this.messages,
    input: input ?? this.input,
    generating: generating ?? this.generating,
    activeModel: activeModel ?? this.activeModel,
    activeModelPath: activeModelPath == _sentinel
        ? this.activeModelPath
        : activeModelPath as String?,
    connection: connection ?? this.connection,
    availableModels: availableModels ?? this.availableModels,
    showModelSelector: showModelSelector ?? this.showModelSelector,
    engineOnline: engineOnline ?? this.engineOnline,
    liveTps: liveTps == _sentinel ? this.liveTps : liveTps as double?,
    streamingText: streamingText ?? this.streamingText,
    attachments: attachments ?? this.attachments,
    pendingTool: pendingTool == _sentinel
        ? this.pendingTool
        : pendingTool as String?,
    pendingToolDescription: pendingToolDescription == _sentinel
        ? this.pendingToolDescription
        : pendingToolDescription as String?,
  );

  /// Regla de habilitación del composer: siempre habilitado para mejor UX.
  /// El bloqueo ocurre al intentar enviar si no hay motor/modelo.
  bool get canSend => engineOnline || activeModelPath != null;
}
