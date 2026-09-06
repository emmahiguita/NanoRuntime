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

/// Recordatorio del producto (v1: el último consultado con éxito de match).
final class ClientContextEntry {
  final ClientProductContext? product;
  final int atMs;

  const ClientContextEntry({this.product, required this.atMs});

  factory ClientContextEntry.fromJson(Map<String, dynamic> json) =>
      ClientContextEntry(
        product: json['product'] == null
            ? null
            : ClientProductContext.fromJson(
                (json['product'] as Map).cast<String, dynamic>(),
              ),
        atMs: (json['atMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
    if (product != null) 'product': product!.toJson(),
    'atMs': atMs,
  };
}

/// Bloque <CONTEXTO DEL CLIENTE> para el prompt ('' si no hay nada que
/// recordar). Auto-instruido: recuerda la consulta anterior y se ignora si
/// el cliente pide algo distinto.
String formatClientContextBlock(ClientContextEntry? entry) {
  final product = entry?.product;
  if (product == null) return '';
  final days = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(entry!.atMs),
  ).inDays;
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
  'hola', 'holas', 'buenas', 'buenos', 'dias', 'tardes', 'noches',
  'buen', 'dia', 'tarde', 'noche', 'hey', 'saludos', 'que', 'tal',
  'mas', 'como', 'estas', 'esta', 'todo', 'bien', 'vos', 'tu', 'ola',
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
/// sin referencia explícita ni producto mencionado.
const Set<String> dependentReplyTokens = {
  'si', 'no', 'dale', 'listo', 'ok', 'okay', 'perfecto', 'cuanto',
  'cuantos', 'cuantas', 'cual', 'cuales', 'cuando', 'manana', 'hoy',
  'vale',
};

/// CONTEXT-GATE-01 — tokens de referencia explícita a lo conversado antes
/// ("ese", "el anterior", "el que te dije"). No matchean catálogo: son la
/// señal de que el recuerdo SÍ aplica.
const Set<String> referenceTokens = {
  'ese', 'esa', 'esos', 'esas', 'aquel', 'aquella', 'aquellos',
  'aquellas', 'anterior', 'mismo', 'misma', 'dije', 'pregunte',
  'pregunto', 'dicho', 'contaste',
};

/// CONTEXT-GATE-01 — decisión determinista de si el recuerdo de producto
/// entra al prompt para ESTE mensaje. Orden de prioridad:
/// 1. Sin recuerdo → nada.
/// 2. Referencia explícita → recuerdo (resuelve "ese"/"el anterior").
/// 3. Respuesta corta dependiente ("sí", "cuánto") → recuerdo (depende del
///    turno activo).
/// 4. Producto explícito en el mensaje → nada: <DATOS DEL NEGOCIO> ya trae
///    los hechos frescos del selector; duplicar el recuerdo incita eco.
/// 5. Resto (saludo puro, tema nuevo, cierre social) → nada: el recuerdo
///    viejo no reactiva temas que el cliente no trajo.
String clientContextBlockForTurn({
  required ClientContextEntry? entry,
  required String messageText,
  required BusinessFacts facts,
}) {
  if (entry?.product == null) return '';
  final tokens = tokenizeText(normalizeText(messageText));
  if (tokens.isEmpty) return '';
  if (tokens.any(referenceTokens.contains)) {
    return formatClientContextBlock(entry);
  }
  if (tokens.length <= 2 && tokens.every(dependentReplyTokens.contains)) {
    return formatClientContextBlock(entry);
  }
  if (selectFactsForMessage(messageText, facts).products.isNotEmpty) {
    return '';
  }
  return '';
}

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
        jsonEncode({
          for (final e in state.entries) e.key: e.value.toJson(),
        }),
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

  /// Registra el producto que el cliente consultó en [message]: se matchea
  /// contra el catálogo con el MISMO selector determinista del prompt
  /// (una sola fuente de verdad; sin producto matcheado no se recuerda nada).
  Future<void> rememberProductFrom(
    String conversationId,
    String message,
    BusinessFacts facts,
  ) async {
    if (conversationId.isEmpty) return;
    final selection = selectFactsForMessage(message, facts);
    if (selection.products.isEmpty) return;
    final product = selection.products.first;
    final entry = ClientContextEntry(
      product: ClientProductContext(
        name: product.name,
        details: product.details,
        priceLabel: product.priceLabel,
        atMs: DateTime.now().millisecondsSinceEpoch,
      ),
      atMs: DateTime.now().millisecondsSinceEpoch,
    );
    state = {...state, conversationId: entry};
    await _store.save(state);
  }
}

final conversationStateStoreProvider = Provider<ConversationStateStore>(
  (ref) => const ConversationStateStore(),
);

final conversationStateNotifierProvider =
    StateNotifierProvider<ConversationStateNotifier,
        Map<String, ClientContextEntry>>((ref) {
      final notifier = ConversationStateNotifier(
        ref.watch(conversationStateStoreProvider),
      );
      notifier.ready;
      return notifier;
    });
