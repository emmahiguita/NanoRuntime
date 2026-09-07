/// WA-STATE-01 — estado conversacional del cliente (por conversación).
///
/// Un turno suele necesitar lo que el cliente consultó ANTES: "¿y el que te
/// pregunté ayer?", "ese teléfono negro". Meter 8 mensajes al prompt ayuda,
/// pero el estado estructurado es determinista y barato: cuando un turno
/// matchea un producto del catálogo (el MISMO selector determinista de
/// WA-BUSINESS-02), se recuerda {producto, variante, precio, cuándo} para
/// esa conversación y viaja al prompt como <CONTEXTO DEL CLIENTE>.
///
/// CONTEXT-GATE-01 — MEMORIA DISPONIBLE != MEMORIA RELEVANTE: el recuerdo
/// NO entra al prompt por defecto. `clientContextBlockForTurn` decide
/// determinista según el mensaje ACTUAL (referencia explícita, respuesta
/// corta dependiente, producto explícito o nada). Evidencia física del
/// fallo: "Hola" tras una consulta del Negro respondió con el Negro y su
/// precio — el 1.5B no ignora contexto inyectado por orden textual; la
/// corrección es que lo irrelevante nunca llegue al prompt.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../business/business_facts.dart';
import '../business/fact_selector.dart';
import '../storage/automation_db_store_client.dart';

/// Recordatorio estructurado de la última consulta de producto.
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

/// Recordatorio del producto (v1: el último consultado con éxito de match)
/// + estado del turno (Ronda 3: pregunta pendiente y cierre de tema).
final class ClientContextEntry {
  final ClientProductContext? product;

  /// Última pregunta que Nano dejó abierta (reply enviado terminado en '?').
  /// '' = sin pregunta pendiente. Resuelve "sí"/"M"/"mañana" contra ELLA,
  /// no contra el último producto.
  final String pendingQuestion;

  /// 'active' = tema comercial en curso; 'resolved' = el cliente cerró
  /// ("gracias"/"listo gracias"); '' = sin tema. Un tema resuelto NO
  /// reaparece con saludos ni respuestas dependientes sin pregunta.
  final String topicStatus;

  final int atMs;

  const ClientContextEntry({
    this.product,
    this.pendingQuestion = '',
    this.topicStatus = '',
    required this.atMs,
  });

  factory ClientContextEntry.fromJson(Map<String, dynamic> json) =>
      ClientContextEntry(
        product: json['product'] == null
            ? null
            : ClientProductContext.fromJson(
                (json['product'] as Map).cast<String, dynamic>(),
              ),
        pendingQuestion: (json['pendingQuestion'] as String?) ?? '',
        topicStatus: (json['topicStatus'] as String?) ?? '',
        atMs: (json['atMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
    if (product != null) 'product': product!.toJson(),
    'pendingQuestion': pendingQuestion,
    'topicStatus': topicStatus,
    'atMs': atMs,
  };
}

/// Bloque <CONTEXTO DEL CLIENTE> para el prompt ('' si no hay nada que
/// recordar). Auto-instruido: recuerda la consulta anterior y se ignora si
/// el cliente pide algo distinto.
String formatClientContextBlock(ClientContextEntry? entry) {
  final product = entry?.product;
  if (product == null) return '';
  final days = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(entry!.atMs))
      .inDays;
  final when = days <= 0
      ? 'hoy'
      : days == 1
      ? 'ayer'
      : 'hace $days días';
  return '''
<CONTEXTO DEL CLIENTE>
Consulta anterior de ESTE cliente: ${product.label} por ${product.priceLabel}
($when). Usa este recuerdo para resolver referencias como "el que te
pregunté", "ese teléfono", "la negra". Si el cliente pide algo distinto o el
recuerdo no aplica, ignóralo por completo.
</CONTEXTO DEL CLIENTE>''';
}

/// CONTEXT-GATE-01 — tokens de saludo puro. Si TODOS los tokens del mensaje
/// caen aquí, es un saludo: el turno no reactiva contexto comercial.
const Set<String> greetingTokens = {
  'hola',
  'holas',
  'buenas',
  'buenos',
  'dias',
  'tardes',
  'noches',
  'buen',
  'dia',
  'tarde',
  'noche',
  'hey',
  'saludos',
  'que',
  'tal',
  'mas',
  'como',
  'estas',
  'esta',
  'todo',
  'bien',
  'vos',
  'tu',
  'ola',
  // P0-ROUTE — saludos casuales del español coloquial: "oe", "¿estás ahí?"
  // ("estas ahi" = todo el mensaje en el set → saludo puro → PERSONAL).
  'oe',
  'ahi',
};

/// ¿Saludo/social puro? Determinista: cada token del mensaje pertenece a
/// [greetingTokens]. "hola, ¿tienen el negro?" NO es puro ('tienen' fuera).
bool isPureGreeting(String messageText) {
  final tokens = tokenizeText(normalizeText(messageText));
  if (tokens.isEmpty) return false;
  return tokens.every(greetingTokens.contains);
}

/// CONTEXT-GATE-01 — tokens de respuesta corta dependiente del turno
/// anterior ("sí", "dale", "cuánto"): solo estos re-activan el recuerdo
/// sin referencia explícita ni producto mencionado. OJO: "vale" está
/// FUERA — "vale" suele ser confirmación ("de acuerdo"), no consulta de
/// precio; "¿cuánto vale?" igual activa por 'cuanto'. Inyectar recuerdo
/// con un "vale" de cierre incita eco del producto viejo (P1).
const Set<String> dependentReplyTokens = {
  'si',
  'no',
  'dale',
  'listo',
  'ok',
  'okay',
  'perfecto',
  'cuanto',
  'cuantos',
  'cuantas',
  'cual',
  'cuales',
  'cuando',
  'manana',
  'hoy',
};

/// CONTEXT-GATE-01 — tokens de referencia explícita a lo conversado antes
/// ("ese", "el anterior", "el que te dije"). No matchean catálogo: son la
/// señal de que el recuerdo SÍ aplica.
const Set<String> referenceTokens = {
  'ese',
  'esa',
  'esos',
  'esas',
  'aquel',
  'aquella',
  'aquellos',
  'aquellas',
  'anterior',
  'mismo',
  'misma',
  'dije',
  'pregunte',
  'pregunto',
  'dicho',
  'contaste',
};

/// CONTEXT-GATE-01 — señales deterministas del gating para ESTE mensaje.
/// Una sola fuente: la decisión de [clientContextBlockForTurn] y la traza
/// diagnóstica [ctx:gate] leen lo MISMO (sin divergencia posible).
({bool reference, bool dependent, bool explicitProduct}) contextSignalsFor(
  String messageText,
  BusinessFacts facts,
) {
  final tokens = tokenizeText(normalizeText(messageText));
  return (
    reference: tokens.any(referenceTokens.contains),
    dependent:
        tokens.isNotEmpty &&
        tokens.length <= 2 &&
        tokens.every(dependentReplyTokens.contains),
    explicitProduct: selectFactsForMessage(
      messageText,
      facts,
    ).products.isNotEmpty,
  );
}

/// Ronda 3 — bloque <PREGUNTA PENDIENTE>: Nano dejó una pregunta abierta y
/// el mensaje corto actual probablemente la responde. Auto-instruido: si no
/// encaja, se ignora (jamás desplaza al mensaje actual).
String formatPendingQuestionBlock(ClientContextEntry entry) {
  final pending = entry.pendingQuestion.trim();
  if (pending.isEmpty) return '';
  return '''
<PREGUNTA PENDIENTE>
Nano preguntó antes: "$pending". El mensaje actual del cliente probablemente
la responde ("sí", "no", "M", "mañana" = respuesta a ESTA pregunta, no una
consulta nueva). Responde a partir de ella. Si el mensaje no encaja con la
pregunta, ignórala por completo.
</PREGUNTA PENDIENTE>''';
}

/// CONTEXT-GATE-01 — decisión determinista de si el recuerdo de producto
/// entra al prompt para ESTE mensaje. Orden de prioridad:
/// 1. Sin recuerdo ni pregunta pendiente → nada.
/// 2. Referencia explícita → recuerdo (resuelve "ese"/"el anterior"),
///    incluso con tema resuelto.
/// 3. Producto explícito en el mensaje → nada: <DATOS DEL NEGOCIO> ya trae
///    los hechos frescos del selector; duplicar el recuerdo incita eco.
/// 4. Pregunta de precio ("cuánto") → recuerdo (el precio es del producto
///    activo).
/// 5. Pregunta pendiente de Nano + mensaje corto (≤3 tokens, sin producto
///    explícito) → bloque <PREGUNTA PENDIENTE>: "sí"/"M"/"mañana" resuelven
///    contra ella, no contra el último producto.
/// 6. Respuesta corta dependiente ("sí", "cuánto") con tema activo → recuerdo.
/// 7. Resto (saludo puro, tema nuevo, cierre social) → nada.
String clientContextBlockForTurn({
  required ClientContextEntry? entry,
  required String messageText,
  required BusinessFacts facts,
}) {
  if (entry?.product == null && (entry?.pendingQuestion ?? '').isEmpty) {
    return '';
  }
  final signals = contextSignalsFor(messageText, facts);
  if (signals.reference) return formatClientContextBlock(entry);
  if (signals.explicitProduct) return '';
  final tokens = tokenizeText(normalizeText(messageText));
  // any, no every: "¿cuánto vale?" trae 'cuanto' (precio) Y 'vale' (fuera
  // del set); la señal de precio gana aunque haya tokens extra.
  if (tokens.isNotEmpty && tokens.any(priceQuestionTokens.contains)) {
    return formatClientContextBlock(entry);
  }
  if ((entry?.pendingQuestion ?? '').isNotEmpty &&
      tokens.isNotEmpty &&
      tokens.length <= 3) {
    return formatPendingQuestionBlock(entry!);
  }
  if (signals.dependent &&
      entry?.topicStatus != 'resolved' &&
      entry?.product != null) {
    return formatClientContextBlock(entry);
  }
  return '';
}

/// CONTEXT-GATE-01 — tokens de consulta de precio: activan el recuerdo del
/// producto incluso con pregunta pendiente ("¿cuánto vale?" pregunta por el
/// PRECIO del producto activo, no responde la pregunta pendiente).
const Set<String> priceQuestionTokens = {
  'cuanto',
  'cuantos',
  'cuantas',
  'precio',
  'precios',
  'coste',
  'cuesta',
};

/// Persistencia (sección `convstate` del AutomationStoreDb).
class ConversationStateStore {
  const ConversationStateStore();

  static const section = 'convstate';

  Future<Map<String, ClientContextEntry>> load() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(section);
      if (raw == null || raw.isEmpty) return const {};
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        for (final e in map.entries)
          e.key: ClientContextEntry.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      };
    } on Object {
      return const {};
    }
  }

  Future<bool> save(Map<String, ClientContextEntry> state) =>
      AutomationDbStoreClient.instance.putSection(
        section,
        jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
      );
}

final class ConversationStateNotifier
    extends StateNotifier<Map<String, ClientContextEntry>> {
  ConversationStateNotifier(this._store) : super(const {});

  final ConversationStateStore _store;
  Future<void>? _loading;

  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      state = await _store.load();
    } on Object {
      // Sin estado: empieza vacío (los recordatorios se construyen solos).
    }
  }

  /// Ronda 3 — registra el turno completo para ESTA conversación:
  /// 1. Producto consultado por el cliente (selector determinista, una sola
  ///    fuente; sin match se conserva el recordado antes).
  /// 2. Pregunta pendiente: el reply de Nano terminó en '?' → esa pregunta
  ///    queda abierta para el próximo turno; sin '?' se limpia (la anterior
  ///    ya fue respondida o abandonada).
  /// 3. Tema: match de producto → 'active'; agradecimiento del cliente
  ///    ("gracias"/"perfecto") → 'resolved'; si no, conserva el anterior.
  Future<void> recordTurn({
    required String conversationId,
    required String userText,
    required String nanoReply,
    required BusinessFacts facts,
  }) async {
    if (conversationId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = state[conversationId];
    final selection = selectFactsForMessage(userText, facts);
    final product = selection.products.isEmpty
        ? existing?.product
        : ClientProductContext(
            name: selection.products.first.name,
            details: selection.products.first.details,
            priceLabel: selection.products.first.priceLabel,
            atMs: now,
          );
    final entry = ClientContextEntry(
      product: product,
      pendingQuestion: _pendingQuestionFrom(nanoReply),
      topicStatus: _topicStatusFor(
        userText,
        hasProductMatch: selection.products.isNotEmpty,
        previous: existing?.topicStatus ?? '',
      ),
      atMs: now,
    );
    state = {...state, conversationId: entry};
    await _store.save(state);
  }

  /// P1-FIX — pendingQuestion solo cuando el reply ESPERA un dato o una
  /// confirmación del cliente (talla/cantidad/fecha/color/confirmación).
  /// Antes cualquier '?' creaba dependencia: "¿En qué puedo ayudarte?" o
  /// "¿Cómo estás?" convertían el siguiente mensaje corto en una respuesta
  /// pendiente y heredaba contexto ajeno. Ronda 3 C01-C04 se conserva:
  /// "¿quieres que revise disponibilidad?" contiene 'quieres' y sigue
  /// generando pregunta pendiente. (Capado: un reply completo de 500 chars
  /// no es una pregunta útil para el prompt.)
  static String _pendingQuestionFrom(String nanoReply) {
    final reply = nanoReply.trim();
    if (!reply.contains('?')) return '';
    final asked = normalizeText(reply).split('?').first.toLowerCase();
    // Cortesía pura: el modelo abre diálogo o saluda; no espera un dato.
    if (_courtesyQuestions.any(asked.contains)) return '';
    // EXPECTED REPLY: solo si pide un dato o confirmación concreta.
    if (!_expectationTokens.any(asked.contains)) return '';
    final question = reply.length <= 160 ? reply : reply.substring(0, 160);
    return question;
  }

  static const Set<String> _courtesyQuestions = {
    'en que puedo ayudarte',
    'como estas',
    'como te va',
    'no te parece',
    'que necesitas',
    'te ayudo',
    'que tal',
  };

  static const List<String> _expectationTokens = [
    'quieres',
    'cuantos',
    'cuantas',
    'talla',
    'color',
    'fecha',
    'confirma',
    'confirmo',
    'deseas',
    'te gustaria',
    'cantidad',
    'cuando',
    'donde',
    'cuanto',
    'reviso',
    'te envio',
    'que dia',
    'te parece',
  ];

  /// Cierre de tema: el cliente agradeció ("gracias"/"perfecto") → resolved.
  /// Match de producto nuevo → active. Sin señal → conserva el anterior.
  static String _topicStatusFor(
    String userText, {
    required bool hasProductMatch,
    required String previous,
  }) {
    if (hasProductMatch) return 'active';
    final tokens = tokenizeText(normalizeText(userText));
    if (tokens.contains('gracias') || tokens.contains('perfecto')) {
      return 'resolved';
    }
    return previous;
  }
}

final conversationStateStoreProvider = Provider<ConversationStateStore>(
  (ref) => const ConversationStateStore(),
);

final conversationStateNotifierProvider =
    StateNotifierProvider<
      ConversationStateNotifier,
      Map<String, ClientContextEntry>
    >((ref) {
      final notifier = ConversationStateNotifier(
        ref.watch(conversationStateStoreProvider),
      );
      notifier.ready;
      return notifier;
    });
