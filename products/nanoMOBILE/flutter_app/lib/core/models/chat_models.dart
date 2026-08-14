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

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final double? tps;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.tps,
    this.status = MessageStatus.sent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'tps': tps,
    'status': status.name,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    sender: MessageSender.values.byName(json['sender'] as String),
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    tps: (json['tps'] as num?)?.toDouble(),
    status: MessageStatus.values.byName(json['status'] as String),
  );
}

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
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? input,
    bool? generating,
    String? activeModel,
    String? activeModelPath,
    ModelConnectionState? connection,
    List<String>? availableModels,
    bool? showModelSelector,
    bool? engineOnline,
    double? liveTps,
    String? streamingText,
  }) => ChatState(
    messages: messages ?? this.messages,
    input: input ?? this.input,
    generating: generating ?? this.generating,
    activeModel: activeModel ?? this.activeModel,
    activeModelPath: activeModelPath ?? this.activeModelPath,
    connection: connection ?? this.connection,
    availableModels: availableModels ?? this.availableModels,
    showModelSelector: showModelSelector ?? this.showModelSelector,
    engineOnline: engineOnline ?? this.engineOnline,
    liveTps: liveTps ?? this.liveTps,
    streamingText: streamingText ?? this.streamingText,
  );
}
