/// QUÉ HACE:
/// Define los modelos de datos estructurados para el estado conversacional
/// del cliente (contexto de producto, preguntas pendientes y hebras de temas abiertos).
///
/// CÓMO FUNCIONA:
/// Modela [ClientProductContext] (último producto validado), [ClientTopicThread]
/// (seguimiento de intenciones múltiples abiertas como envíos o disponibilidad)
/// y [ClientContextEntry] (snapshot persistible en la base de datos).
///
/// POR QUÉ:
/// Permite descomponer mensajes multitema (ej: precio + disponibilidad + despacho)
/// sin perder de vista qué obligaciones fueron resueltas y cuáles siguen abiertas,
/// manteniendo un archivo modular con menos de 200 líneas.
library;

/// Recordatorio estructurado de la última consulta de producto validada.
final class ClientProductContext {
  final String name;
  final String details;
  final String priceLabel;
  final int atMs;

  const ClientProductContext({
    required this.name,
    required this.details,
    required this.priceLabel,
    required this.atMs,
  });

  String get label {
    final variant = details.trim();
    return variant.isEmpty ? name : '$name ($variant)';
  }

  factory ClientProductContext.fromJson(Map<String, dynamic> json) =>
      ClientProductContext(
        name: (json['name'] as String?) ?? '',
        details: (json['details'] as String?) ?? '',
        priceLabel: (json['price'] as String?) ?? '',
        atMs: (json['atMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'details': details,
    'price': priceLabel,
    'atMs': atMs,
  };
}

/// Hebra de tema o intención abierta dentro de la conversación.
final class ClientTopicThread {
  final String id;
  final String topic;
  final String status; // 'open', 'resolved', 'pending_data'
  final String details;
  final String pendingObligation;

  const ClientTopicThread({
    required this.id,
    required this.topic,
    this.status = 'open',
    this.details = '',
    this.pendingObligation = '',
  });

  bool get isOpen => status == 'open' || status == 'pending_data';

  factory ClientTopicThread.fromJson(Map<String, dynamic> json) =>
      ClientTopicThread(
        id: (json['id'] as String?) ?? '',
        topic: (json['topic'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'open',
        details: (json['details'] as String?) ?? '',
        pendingObligation: (json['pendingObligation'] as String?) ?? '',
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'topic': topic,
    'status': status,
    'details': details,
    'pendingObligation': pendingObligation,
  };
}

/// Snapshot estructurado del estado conversacional por cliente.
final class ClientContextEntry {
  final ClientProductContext? product;
  final String pendingQuestion;
  final String topicStatus;
  final String pendingKind;
  final List<ClientTopicThread> openThreads;
  final int atMs;

  const ClientContextEntry({
    this.product,
    this.pendingQuestion = '',
    this.topicStatus = '',
    this.pendingKind = '',
    this.openThreads = const [],
    required this.atMs,
  });

  factory ClientContextEntry.fromJson(Map<String, dynamic> json) {
    final rawThreads = json['openThreads'];
    final threads = <ClientTopicThread>[];
    if (rawThreads is List) {
      for (final t in rawThreads) {
        if (t is Map) {
          threads.add(ClientTopicThread.fromJson(t.cast<String, dynamic>()));
        }
      }
    }
    return ClientContextEntry(
      product: json['product'] == null
          ? null
          : ClientProductContext.fromJson(
              (json['product'] as Map).cast<String, dynamic>(),
            ),
      pendingQuestion: (json['pendingQuestion'] as String?) ?? '',
      topicStatus: (json['topicStatus'] as String?) ?? '',
      pendingKind: (json['pendingKind'] as String?) ?? '',
      openThreads: threads,
      atMs: (json['atMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    if (product != null) 'product': product!.toJson(),
    'pendingQuestion': pendingQuestion,
    'topicStatus': topicStatus,
    'pendingKind': pendingKind,
    if (openThreads.isNotEmpty)
      'openThreads': openThreads.map((t) => t.toJson()).toList(),
    'atMs': atMs,
  };

  ClientContextEntry copyWith({
    ClientProductContext? product,
    String? pendingQuestion,
    String? topicStatus,
    String? pendingKind,
    List<ClientTopicThread>? openThreads,
    int? atMs,
  }) {
    return ClientContextEntry(
      product: product ?? this.product,
      pendingQuestion: pendingQuestion ?? this.pendingQuestion,
      topicStatus: topicStatus ?? this.topicStatus,
      pendingKind: pendingKind ?? this.pendingKind,
      openThreads: openThreads ?? this.openThreads,
      atMs: atMs ?? this.atMs,
    );
  }
}
